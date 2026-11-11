defmodule Lux.Web3.TransactionManager do
  @moduledoc """
  EIP-1559 preflight, economical batching and explicit private transaction routing.

  Transactions use JSON-RPC string keys and hex quantities. No keys are stored
  and no transactions are signed implicitly. `prepare/2` simulates at `pending`,
  estimates gas with a buffer and checks the native balance against the fee cap.
  `plan_batch/4` compares real estimates before recommending a Multicall3 batch.

  Nonces are read from `pending`; concurrent writers must serialize their own
  nonce allocation. Simulation cannot guarantee execution against future state.
  """

  alias Lux.Web3.Gas
  alias Lux.Web3.RPC
  alias Lux.Web3.TransactionBatch

  @type result :: {:ok, map()} | {:error, term()}
  @quantity_fields ~w(value nonce chainId gas maxFeePerGas maxPriorityFeePerGas type)
  @allowed_fields ~w(from to data accessList) ++ @quantity_fields

  @doc "Fetches 20 blocks of fee history and predicts fees (`Gas.quote/2` options apply)."
  @spec quote(keyword()) :: result()
  def quote(opts) do
    with {:ok, history} <- RPC.request("eth_feeHistory", ["0x14", "latest", [10, 50, 90]], opts) do
      Gas.quote(history, opts)
    end
  end

  @doc "Returns a simulated unsigned transaction, fee quote and integer cost report."
  @spec prepare(map(), keyword()) :: result()
  def prepare(tx, opts) do
    with {:ok, tx} <- normalize(tx),
         {:ok, fees} <- __MODULE__.quote(opts) do
      do_prepare(tx, fees, opts)
    end
  end

  @doc """
  Builds and simulates an atomic batch, recommending it only when its gas
  estimate is lower than the sum of individual estimates. The result contains
  prepared plans in `:plans`, with consecutive nonces for the individual path.
  All calls must be independent, zero-value, and safe for a changed sender.
  """
  @spec plan_batch([map()], String.t(), String.t(), keyword()) :: result()
  def plan_batch(calls, from, contract, opts) do
    with true <- Gas.address?(from),
         {:ok, batch_tx} <- TransactionBatch.build(calls, contract, opts),
         {:ok, code} <- RPC.request("eth_getCode", [contract, "pending"], opts),
         true <- Gas.data?(code) and code != "0x",
         {:ok, fees} <- __MODULE__.quote(opts),
         {:ok, nonce_hex} <- RPC.request("eth_getTransactionCount", [from, "pending"], opts),
         {:ok, nonce} <- Gas.quantity(nonce_hex),
         {:ok, individuals} <- prepare_calls(calls, from, nonce, fees, opts),
         {:ok, batch} <-
           do_prepare(
             Map.merge(batch_tx, %{"from" => from, "nonce" => Gas.hex(nonce)}),
             fees,
             opts
           ) do
      individual_gas = Enum.sum(Enum.map(individuals, & &1.cost.gas_estimate))
      savings = individual_gas - batch.cost.gas_estimate
      plans = if savings > 0, do: [batch], else: individuals
      reserve = Enum.sum(Enum.map(plans, & &1.cost.required_balance_wei))

      with :ok <- check_balance(from, reserve, opts) do
        {:ok,
         %{
           strategy: if(savings > 0, do: :batch, else: :individual),
           individual_gas: individual_gas,
           batch_gas: batch.cost.gas_estimate,
           gas_saved: max(savings, 0),
           estimated_savings_wei: max(savings, 0) * fees.estimated_fee_per_gas,
           plans: plans
         }}
      end
    else
      false -> {:error, :invalid_batch_sender_or_contract}
      error -> error
    end
  end

  @doc """
  Submits signed bytes once. MEV protection is on by default and requires an
  explicit `:private_rpc_url` supporting `eth_sendRawTransaction` (for example
  a Protect RPC endpoint). Private errors never fall back to the public RPC.
  Set `mev_protection: false` explicitly to use `:rpc_url`.

  Use `:private_req_options` for private endpoint authentication; public
  `:req_options` are never forwarded to it. Ambiguous responses return
  `{:error, {:submission_unknown, %{transaction_hash: hash, reason: reason}}}`;
  reconcile that locally computed hash before deciding to send again.
  """
  @spec submit(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def submit(raw, opts) do
    with true <- Gas.data?(raw) and raw != "0x",
         {:ok, endpoint} <- submission_endpoint(opts) do
      request_opts_key =
        if Keyword.get(opts, :mev_protection, true), do: :private_req_options, else: :req_options

      request_opts =
        opts
        |> Keyword.put(:rpc_url, endpoint)
        |> Keyword.put(:req_options, Keyword.get(opts, request_opts_key, []))

      hash = raw |> Ethers.Utils.hex_decode!() |> ExKeccak.hash_256() |> Ethers.Utils.hex_encode()
      result = RPC.request("eth_sendRawTransaction", [raw], request_opts)
      submission_result(result, hash)
    else
      false -> {:error, :invalid_signed_transaction}
      error -> error
    end
  end

  @doc "Preflights, calls the supplied signer, then submits once through the selected route."
  @spec execute(map(), (map() -> {:ok, String.t()} | {:error, term()}), keyword()) :: result()
  def execute(tx, signer, opts) when is_function(signer, 1) do
    with {:ok, plan} <- prepare(tx, opts),
         {:ok, raw} <- signer.(plan.transaction),
         {:ok, hash} <- submit(raw, opts) do
      {:ok, Map.put(plan, :transaction_hash, hash)}
    end
  end

  defp do_prepare(tx, fees, opts) do
    with {:ok, chain_hex} <- RPC.request("eth_chainId", [], opts),
         {:ok, chain} <- Gas.quantity(chain_hex),
         :ok <- check_chain(tx, chain),
         {:ok, nonce} <- nonce(tx, opts),
         {:ok, tx} <- apply_fees(tx, fees),
         tx = Map.merge(tx, %{"chainId" => Gas.hex(chain), "nonce" => nonce, "type" => "0x2"}),
         {:ok, simulation} <- simulate(tx, opts),
         {:ok, limit} <- gas_limit(tx, simulation.gas_estimate, opts),
         {:ok, cap} <- Gas.quantity(tx["maxFeePerGas"]),
         {:ok, tip} <- Gas.quantity(tx["maxPriorityFeePerGas"]),
         {:ok, value} <- Gas.quantity(Map.get(tx, "value", "0x0")),
         {:ok, cost} <-
           Gas.cost(simulation.gas_estimate, limit, fees.base_fee_per_gas, cap, tip, value),
         :ok <- check_balance(tx["from"], cost.required_balance_wei, opts) do
      {:ok,
       %{
         transaction: Map.put(tx, "gas", Gas.hex(limit)),
         fees: fees,
         simulation: simulation,
         cost: cost
       }}
    end
  end

  defp simulate(tx, opts) do
    with {:ok, returned} <- RPC.request("eth_call", [tx, "pending"], opts),
         true <- Gas.data?(returned),
         {:ok, gas} <- RPC.request("eth_estimateGas", [tx, "pending"], opts),
         {:ok, estimate} <- Gas.quantity(gas),
         true <- estimate > 0 do
      {:ok, %{return_data: returned, gas_estimate: estimate}}
    else
      false -> {:error, :invalid_simulation_result}
      error -> error
    end
  end

  defp normalize(tx) when is_map(tx) do
    if valid_transaction?(tx) do
      Enum.reduce_while(@quantity_fields, {:ok, tx}, &normalize_quantity/2)
    else
      {:error, :invalid_eip1559_transaction}
    end
  end

  defp normalize(_), do: {:error, :invalid_eip1559_transaction}

  defp valid_transaction?(tx) do
    Enum.all?(Map.keys(tx), &(&1 in @allowed_fields)) and
      Gas.address?(tx["from"]) and Gas.address?(tx["to"]) and
      Gas.data?(Map.get(tx, "data", "0x")) and
      Map.get(tx, "type", "0x2") in [2, "0x2"] and
      valid_access_list?(Map.get(tx, "accessList", []))
  end

  defp normalize_quantity(field, {:ok, tx}) do
    case Map.fetch(tx, field) do
      {:ok, value} ->
        case Gas.quantity(value) do
          {:ok, integer} -> {:cont, {:ok, Map.put(tx, field, Gas.hex(integer))}}
          _ -> {:halt, {:error, {:invalid_quantity, field}}}
        end

      :error ->
        {:cont, {:ok, tx}}
    end
  end

  defp valid_access_list?(entries) when is_list(entries) do
    Enum.all?(entries, fn
      %{"address" => address, "storageKeys" => keys} when is_list(keys) ->
        Gas.address?(address) and Enum.all?(keys, &(Gas.data?(&1) and byte_size(&1) == 66))

      _ ->
        false
    end)
  end

  defp valid_access_list?(_), do: false

  defp check_chain(tx, chain) do
    case Map.fetch(tx, "chainId") do
      :error ->
        :ok

      {:ok, value} ->
        if Gas.quantity(value) == {:ok, chain}, do: :ok, else: {:error, :chain_id_mismatch}
    end
  end

  defp nonce(%{"nonce" => nonce}, _opts), do: {:ok, nonce}

  defp nonce(tx, opts) do
    with {:ok, value} <- RPC.request("eth_getTransactionCount", [tx["from"], "pending"], opts),
         {:ok, integer} <- Gas.quantity(value) do
      {:ok, Gas.hex(integer)}
    end
  end

  defp apply_fees(tx, fees) do
    case {Map.fetch(tx, "maxFeePerGas"), Map.fetch(tx, "maxPriorityFeePerGas")} do
      {:error, :error} ->
        {:ok,
         Map.merge(tx, %{
           "maxFeePerGas" => Gas.hex(fees.max_fee_per_gas),
           "maxPriorityFeePerGas" => Gas.hex(fees.max_priority_fee_per_gas)
         })}

      {{:ok, cap}, {:ok, tip}} ->
        with {:ok, cap} <- Gas.quantity(cap),
             {:ok, tip} <- Gas.quantity(tip),
             true <- cap >= tip and cap >= fees.base_fee_per_gas do
          {:ok, tx}
        else
          _ -> {:error, :invalid_fee_caps}
        end

      _ ->
        {:error, :both_fee_caps_required}
    end
  end

  defp gas_limit(tx, estimate, opts) do
    buffer = Keyword.get(opts, :gas_buffer_percent, 20)

    if is_integer(buffer) and buffer in 0..100 do
      case Map.fetch(tx, "gas") do
        {:ok, quantity} ->
          with {:ok, limit} <- Gas.quantity(quantity),
               true <- limit >= estimate do
            {:ok, limit}
          else
            _ -> {:error, :gas_limit_below_estimate}
          end

        :error ->
          {:ok, Gas.ceil_div(estimate * (100 + buffer), 100)}
      end
    else
      {:error, :invalid_gas_buffer}
    end
  end

  defp check_balance(from, required, opts) do
    with {:ok, quantity} <- RPC.request("eth_getBalance", [from, "pending"], opts),
         {:ok, balance} <- Gas.quantity(quantity) do
      if balance >= required, do: :ok, else: {:error, :insufficient_balance}
    end
  end

  defp prepare_calls(calls, from, nonce, fees, opts) do
    calls
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {call, offset}, {:ok, acc} ->
      tx = Map.merge(call, %{"from" => from, "nonce" => Gas.hex(nonce + offset)})

      result = with {:ok, normalized} <- normalize(tx), do: do_prepare(normalized, fees, opts)

      case result do
        {:ok, plan} -> {:cont, {:ok, [plan | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, plans} -> {:ok, Enum.reverse(plans)}
      error -> error
    end
  end

  defp submission_endpoint(opts) do
    key = if Keyword.get(opts, :mev_protection, true), do: :private_rpc_url, else: :rpc_url

    case Keyword.get(opts, key) do
      url when is_binary(url) and byte_size(url) > 0 -> {:ok, url}
      _ -> {:error, {key, :required}}
    end
  end

  defp submission_result({:ok, returned}, hash) do
    if is_binary(returned) and String.downcase(returned) == hash do
      {:ok, hash}
    else
      unknown_submission(hash, :unexpected_transaction_hash)
    end
  end

  defp submission_result({:error, {:rpc, _}} = error, _hash), do: error
  defp submission_result({:error, reason}, hash), do: unknown_submission(hash, reason)

  defp unknown_submission(hash, reason),
    do: {:error, {:submission_unknown, %{transaction_hash: hash, reason: reason}}}
end
