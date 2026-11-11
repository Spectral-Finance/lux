defmodule Lux.Web3.Gas do
  @moduledoc """
  Integer-only EIP-1559 fee prediction, replacement and cost analysis.

  All amounts are in wei. `quote/2` consumes `eth_feeHistory` with reward
  percentiles `[10, 50, 90]`. Its base fee is the last entry (the next block),
  and its fee cap allows for `:blocks` additional full blocks. This is a
  bounded forecast, not an inclusion guarantee.
  """

  @type result :: {:ok, map()} | {:error, term()}

  @doc "Parses a non-negative integer or JSON-RPC hexadecimal quantity."
  @spec quantity(term()) :: {:ok, non_neg_integer()} | {:error, :invalid_quantity}
  def quantity(value) when is_integer(value) and value >= 0, do: {:ok, value}

  def quantity("0x" <> digits) when byte_size(digits) > 0 do
    if Regex.match?(~r/\A[0-9a-fA-F]+\z/, digits) do
      {value, ""} = Integer.parse(digits, 16)
      {:ok, value}
    else
      {:error, :invalid_quantity}
    end
  end

  def quantity(_), do: {:error, :invalid_quantity}

  @doc "Encodes a non-negative integer as a canonical JSON-RPC quantity."
  @spec hex(non_neg_integer()) :: String.t()
  def hex(value) when is_integer(value) and value >= 0 do
    ("0x" <> Integer.to_string(value, 16)) |> String.downcase()
  end

  @doc "Calculates the next Ethereum base fee from a parent block (EIP-1559)."
  @spec next_base_fee(non_neg_integer(), non_neg_integer(), pos_integer()) ::
          {:ok, non_neg_integer()} | {:error, :invalid_block}
  def next_base_fee(base, used, limit)
      when is_integer(base) and base >= 0 and is_integer(used) and used >= 0 and
             is_integer(limit) and limit >= 2 and used <= limit do
    target = div(limit, 2)

    fee =
      cond do
        used > target -> base + max(div(div(base * (used - target), target), 8), 1)
        used < target -> base - div(div(base * (target - used), target), 8)
        true -> base
      end

    {:ok, fee}
  end

  def next_base_fee(_, _, _), do: {:error, :invalid_block}

  @doc """
  Recommends fees using median observed tips and full-block base fee headroom.

  Options: `:speed` (`:slow`, `:standard`, `:fast`), `:blocks` (0..25,
  default 2), `:min_priority_fee` (default 1 gwei).
  """
  @spec quote(map(), keyword()) :: result()
  def quote(history, opts \\ []) do
    speed = Keyword.get(opts, :speed, :standard)
    blocks = Keyword.get(opts, :blocks, 2)
    floor = Keyword.get(opts, :min_priority_fee, 1_000_000_000)

    with true <- speed in [:slow, :standard, :fast],
         true <- is_integer(blocks) and blocks in 0..25,
         true <- is_integer(floor) and floor >= 0,
         {:ok, bases, rewards} <- parse_history(history) do
      index = Enum.find_index([:slow, :standard, :fast], &(&1 == speed))
      tips = rewards |> Enum.map(&Enum.at(&1, index)) |> Enum.sort()
      tip = max(Enum.at(tips, div(length(tips), 2)), floor)
      base = List.last(bases)

      cap =
        Enum.reduce(List.duplicate(nil, blocks), base, fn _, fee ->
          fee + max(div(fee, 8), 1)
        end)

      {:ok,
       %{
         speed: speed,
         horizon_blocks: blocks,
         base_fee_per_gas: base,
         max_priority_fee_per_gas: tip,
         max_fee_per_gas: cap + tip,
         estimated_fee_per_gas: base + tip
       }}
    else
      _ -> {:error, :invalid_fee_history_or_options}
    end
  end

  @doc """
  Bumps both EIP-1559 fee caps, retaining the nonce. `:cancel` replaces the
  operation with a zero-value self transfer. Pass the result through
  `Lux.Web3.TransactionManager.prepare/2` to simulate and estimate it again.

  `:bump_percent` defaults to 10; nodes may require a higher replacement bump.
  """
  @spec replace(map(), non_neg_integer(), :speed_up | :cancel, keyword()) :: result()
  def replace(tx, base_fee, action, opts \\ []) do
    bump = Keyword.get(opts, :bump_percent, 10)

    with true <- is_map(tx) and action in [:speed_up, :cancel],
         true <- is_integer(base_fee) and base_fee >= 0,
         true <- is_integer(bump) and bump in 1..1_000,
         false <- Map.has_key?(tx, "gasPrice"),
         true <- Map.get(tx, "type", "0x2") in [2, "0x2"],
         true <- address?(tx["from"]) and address?(tx["to"]),
         {:ok, _nonce} <- quantity(tx["nonce"]),
         {:ok, old_cap} <- quantity(tx["maxFeePerGas"]),
         {:ok, old_tip} <- quantity(tx["maxPriorityFeePerGas"]),
         true <- old_cap >= old_tip do
      tip = max(ceil_div(old_tip * (100 + bump), 100), old_tip + 1)
      cap = max(max(ceil_div(old_cap * (100 + bump), 100), old_cap + 1), base_fee + tip)

      replacement =
        case action do
          :speed_up ->
            tx

          :cancel ->
            tx
            |> Map.take(["from", "nonce", "chainId", "type"])
            |> Map.merge(%{"to" => tx["from"], "value" => "0x0", "data" => "0x"})
        end

      {:ok,
       Map.merge(replacement, %{
         "maxFeePerGas" => hex(cap),
         "maxPriorityFeePerGas" => hex(tip)
       })}
    else
      _ -> {:error, :invalid_replacement}
    end
  end

  @doc "Reports estimated fees, maximum reserved fees and native balance required."
  @spec cost(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: result()
  def cost(estimate, limit, base, cap, tip, value) do
    if Enum.all?([estimate, limit, base, cap, tip, value], &(is_integer(&1) and &1 >= 0)) and
         limit >= estimate and cap >= base and cap >= tip do
      effective = min(cap, base + tip)

      {:ok,
       %{
         gas_estimate: estimate,
         gas_limit: limit,
         effective_fee_per_gas: effective,
         expected_fee_wei: estimate * effective,
         maximum_fee_wei: limit * cap,
         required_balance_wei: limit * cap + value
       }}
    else
      {:error, :invalid_cost_inputs}
    end
  end

  @doc """
  Evaluates a caller-provided legacy gas-token quote adapter on an explicitly
  pre-London chain. EIP-3529 makes historical refund tokens unsuitable on
  Ethereum; the adapter is never invoked when `london: true`.

  The adapter returns `{:ok, %{refund_wei: n, purchase_wei: n, execution_wei: n}}`.
  This function only evaluates economics; it never buys or burns tokens.
  """
  @spec gas_token_savings(map(), (-> result())) :: result()
  def gas_token_savings(%{london: true}, _adapter),
    do: {:error, :gas_tokens_disabled_after_london}

  def gas_token_savings(%{london: false}, adapter) when is_function(adapter, 0) do
    with {:ok, %{refund_wei: refund, purchase_wei: purchase, execution_wei: execution}} <-
           adapter.(),
         true <- Enum.all?([refund, purchase, execution], &(is_integer(&1) and &1 >= 0)) do
      net = refund - purchase - execution
      {:ok, %{use_token: net > 0, net_savings_wei: net}}
    else
      {:error, _} = error -> error
      _ -> {:error, :invalid_gas_token_quote}
    end
  end

  def gas_token_savings(_, _), do: {:error, :explicit_chain_policy_required}

  @doc "Checks the shape of an Ethereum address (without a checksum assumption)."
  @spec address?(term()) :: boolean()
  def address?(value) when is_binary(value), do: Regex.match?(~r/\A0x[0-9a-fA-F]{40}\z/, value)
  def address?(_), do: false

  @doc "Checks that a value is an even-length, 0x-prefixed byte string."
  @spec data?(term()) :: boolean()
  def data?(value) when is_binary(value), do: Regex.match?(~r/\A0x(?:[0-9a-fA-F]{2})*\z/, value)
  def data?(_), do: false

  @doc false
  @spec ceil_div(non_neg_integer(), pos_integer()) :: non_neg_integer()
  def ceil_div(numerator, denominator), do: div(numerator + denominator - 1, denominator)

  defp parse_history(%{"baseFeePerGas" => bases, "reward" => rewards})
       when is_list(bases) and is_list(rewards) and rewards != [] do
    with true <- length(bases) == length(rewards) + 1,
         {:ok, bases} <- parse_quantities(bases),
         true <- Enum.all?(rewards, &(is_list(&1) and length(&1) == 3)),
         {:ok, flat_rewards} <- rewards |> List.flatten() |> parse_quantities() do
      {:ok, bases, Enum.chunk_every(flat_rewards, 3)}
    else
      _ -> {:error, :invalid_fee_history}
    end
  end

  defp parse_history(_), do: {:error, :invalid_fee_history}

  defp parse_quantities(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case quantity(value) do
        {:ok, number} -> {:cont, {:ok, [number | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
      error -> error
    end
  end
end
