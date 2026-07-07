defmodule Lux.Web3.TransactionManager do
  @moduledoc """
  A GenServer-based transaction manager and queue processor per active wallet address.
  Handles nonce tracking, gas/fee estimation, transaction signing using local signers,
  and automated gas escalation (speed-up) for stuck transactions.
  """

  use GenServer
  require Logger

  @registry Lux.Web3.TransactionManagerRegistry
  @supervisor Lux.Web3.TransactionManagerSupervisor

  # API

  @doc """
  Starts a transaction manager GenServer for a specific address.
  """
  def start_manager(address, encrypted_private_key, opts \\ []) do
    child_spec = {__MODULE__, Keyword.merge(opts, [address: address, encrypted_private_key: encrypted_private_key])}
    DynamicSupervisor.start_child(@supervisor, child_spec)
  end

  @doc """
  Queues a transaction for a wallet address and blocks until the receipt is obtained.
  """
  def send_transaction(address, tx_params, timeout \\ :infinity) do
    case get_manager(address) do
      {:ok, pid} ->
        GenServer.call(pid, {:send_transaction, tx_params}, timeout)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Retrieves or starts the GenServer pid for a given address.
  """
  def get_manager(address) do
    case Registry.lookup(@registry, address) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  # GenServer Callbacks

  def start_link(opts) do
    address = Keyword.fetch!(opts, :address)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(address))
  end

  @impl true
  def init(opts) do
    address = Keyword.fetch!(opts, :address)
    encrypted_private_key = Keyword.fetch!(opts, :encrypted_private_key)
    nonce = Keyword.get(opts, :nonce)

    state = %{
      address: address,
      encrypted_private_key: encrypted_private_key,
      nonce: nonce,
      queue: :queue.new(),
      active_tx: nil,
      timer: nil,
      nonce_initialized: not is_nil(nonce)
    }

    # Lazy nonce init: nonce is fetched on first transaction, not on startup.
    # This decouples wallet creation/import from requiring a live RPC connection.
    {:ok, state}
  end

  @impl true
  def handle_continue(:init_nonce, state) do
    case Ethers.get_transaction_count(state.address) do
      {:ok, nonce} ->
        Logger.debug("Initialized transaction count (nonce) for #{state.address} to #{nonce}")
        {:noreply, %{state | nonce: nonce, nonce_initialized: true}, {:continue, :process_queue}}

      {:error, reason} ->
        Logger.error("Failed to fetch initial nonce for #{state.address}: #{inspect(reason)}. Retrying in 5s.")
        Process.send_after(self(), :init_nonce, 5000)
        {:noreply, state}
    end
  end

  def handle_continue(:process_queue, state) do
    cond do
      state.active_tx != nil ->
        # Already processing an in-flight transaction
        {:noreply, state}

      true ->
        case :queue.out(state.queue) do
          {{:value, tx}, remaining_queue} ->
            case send_and_sign(tx, state) do
              {:ok, tx_hash, gas_opts} ->
                Logger.info("Sent transaction #{inspect(tx.id)}: hash=#{tx_hash}, nonce=#{state.nonce}")
                
                timer = Process.send_after(self(), {:check_receipt, tx.id}, 5000)

                active_tx = %{
                  id: tx.id,
                  tx_hash: tx_hash,
                  nonce: state.nonce,
                  sent_at: DateTime.utc_now(),
                  gas_opts: gas_opts,
                  params: tx.params,
                  reply_to: tx.reply_to
                }

                {:noreply, %{state | queue: remaining_queue, active_tx: active_tx, timer: timer, nonce: state.nonce + 1}}

              {:error, reason} ->
                Logger.error("Transaction signing failed: #{inspect(reason)}")
                GenServer.reply(tx.reply_to, {:error, reason})
                {:noreply, %{state | queue: remaining_queue}, {:continue, :process_queue}}
            end

          {:empty, _} ->
            {:noreply, state}
        end
    end
  end

  @impl true
  def handle_call({:send_transaction, tx_params}, from, state) do
    current_chain_id = get_current_chain_id()

    cond do
      tx_params[:chain_id] && tx_params[:chain_id] != current_chain_id ->
        {:reply, {:error, "Chain ID mismatch: expected #{tx_params[:chain_id]}, got #{current_chain_id}"}, state}

      exceeds_fee_cap?(tx_params) ->
        {:reply, {:error, "Gas price exceeds max fee cap"}, state}

      tx_params[:dry_run] == true ->
        case dry_run_tx(tx_params, state) do
          {:ok, gas_estimate} ->
            simulated_receipt = %{
              "transactionHash" => "0xdryrunhash",
              "blockNumber" => "0x0",
              "status" => "0x1",
              "gasUsed" => Ethers.Utils.integer_to_hex(gas_estimate)
            }
            {:reply, {:ok, simulated_receipt}, state}

          {:error, reason} ->
            {:reply, {:error, "Dry-run failed: #{inspect(reason)}"}, state}
        end

      true ->
        tx = %{id: make_ref(), params: tx_params, reply_to: from}
        new_queue = :queue.in(tx, state.queue)
        new_state = %{state | queue: new_queue}

        # Trigger nonce initialization on first transaction if not yet done
        if state.nonce_initialized do
          {:noreply, new_state, {:continue, :process_queue}}
        else
          {:noreply, new_state, {:continue, :init_nonce}}
        end
    end
  end

  @impl true
  def handle_info(:init_nonce, state) do
    {:noreply, state, {:continue, :init_nonce}}
  end

  def handle_info({:check_receipt, tx_id}, state) do
    if state.active_tx && state.active_tx.id == tx_id do
      active_tx = state.active_tx

      case Ethers.get_transaction_receipt(active_tx.tx_hash) do
        {:ok, receipt} ->
          Logger.info("Transaction mined successfully! Hash: #{active_tx.tx_hash}")
          
          if state.timer, do: Process.cancel_timer(state.timer)
          GenServer.reply(active_tx.reply_to, {:ok, receipt})
          {:noreply, %{state | active_tx: nil, timer: nil}, {:continue, :process_queue}}

        {:error, :transaction_receipt_not_found} ->
          # Check if stuck (> 30 seconds)
          elapsed = DateTime.diff(DateTime.utc_now(), active_tx.sent_at)

          if elapsed > 30 do
            Logger.warning("Transaction #{inspect(active_tx.id)} with hash #{active_tx.tx_hash} is stuck for #{elapsed}s. Attempting speed-up.")

            case speed_up_transaction(active_tx, state) do
              {:ok, new_tx_hash, new_gas_opts} ->
                Logger.info("Replaced transaction #{inspect(active_tx.id)} with new hash: #{new_tx_hash}")
                
                new_active_tx = %{
                  active_tx |
                  tx_hash: new_tx_hash,
                  gas_opts: new_gas_opts,
                  sent_at: DateTime.utc_now()
                }

                timer = Process.send_after(self(), {:check_receipt, tx_id}, 5000)
                {:noreply, %{state | active_tx: new_active_tx, timer: timer}}

              {:error, reason} ->
                Logger.error("Failed to speed up transaction: #{inspect(reason)}")
                timer = Process.send_after(self(), {:check_receipt, tx_id}, 5000)
                {:noreply, %{state | timer: timer}}
            end
          else
            timer = Process.send_after(self(), {:check_receipt, tx_id}, 5000)
            {:noreply, %{state | timer: timer}}
          end

        {:error, reason} ->
          Logger.warning("Error fetching transaction receipt: #{inspect(reason)}")
          timer = Process.send_after(self(), {:check_receipt, tx_id}, 5000)
          {:noreply, %{state | timer: timer}}
      end
    else
      {:noreply, state}
    end
  end

  # Helper / Private Functions

  defp via_tuple(address) do
    {:via, Registry, {@registry, address}}
  end

  defp send_and_sign(tx, state) do
    with {:ok, private_key} <- Lux.Web3.KeyManager.decrypt(state.encrypted_private_key) do
      gas_limit = Map.get(tx.params, :gas_limit) || estimate_gas_limit(tx.params, state)

      gas_opts =
        case estimate_fees() do
          {:ok, %{max_fee_per_gas: max_fee, max_priority_fee_per_gas: priority_fee}} ->
            [max_fee_per_gas: max_fee, max_priority_fee_per_gas: priority_fee]

          {:ok, %{gas_price: price}} ->
            [gas_price: price]

          _ ->
            []
        end

      to_addr = tx.params[:to]
      data_bin = tx.params[:data] || ""
      value = tx.params[:value] || 0

      ethers_tx = %{to: to_addr, data: data_bin}

      send_opts = [
        from: state.address,
        value: value,
        gas: gas_limit,
        nonce: state.nonce,
        signer: Ethers.Signer.Local,
        signer_opts: [private_key: private_key]
      ] ++ gas_opts

      case Ethers.send_transaction(ethers_tx, send_opts) do
        {:ok, tx_hash} -> {:ok, tx_hash, gas_opts}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp speed_up_transaction(active_tx, state) do
    with {:ok, private_key} <- Lux.Web3.KeyManager.decrypt(state.encrypted_private_key) do
      gas_limit = Map.get(active_tx.params, :gas_limit) || estimate_gas_limit(active_tx.params, state)

      new_gas_opts =
        case active_tx.gas_opts do
          [max_fee_per_gas: max_fee, max_priority_fee_per_gas: priority_fee] ->
            [max_fee_per_gas: round(max_fee * 1.15), max_priority_fee_per_gas: round(priority_fee * 1.15)]

          [gas_price: price] ->
            [gas_price: round(price * 1.15)]

          _ ->
            case estimate_fees() do
              {:ok, %{max_fee_per_gas: max_fee, max_priority_fee_per_gas: priority_fee}} ->
                [max_fee_per_gas: round(max_fee * 1.15), max_priority_fee_per_gas: round(priority_fee * 1.15)]

              {:ok, %{gas_price: price}} ->
                [gas_price: round(price * 1.15)]

              _ ->
                []
            end
        end

      to_addr = active_tx.params[:to]
      data_bin = active_tx.params[:data] || ""
      value = active_tx.params[:value] || 0

      ethers_tx = %{to: to_addr, data: data_bin}

      send_opts = [
        from: state.address,
        value: value,
        gas: gas_limit,
        nonce: active_tx.nonce,
        signer: Ethers.Signer.Local,
        signer_opts: [private_key: private_key]
      ] ++ new_gas_opts

      case Ethers.send_transaction(ethers_tx, send_opts) do
        {:ok, tx_hash} -> {:ok, tx_hash, new_gas_opts}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp estimate_gas_limit(params, state) do
    ethers_tx = %{to: params[:to], data: params[:data] || ""}
    opts = [from: state.address, value: params[:value] || 0]

    case Ethers.estimate_gas(ethers_tx, opts) do
      {:ok, gas} -> trunc(gas * 1.1)
      _ -> 100_000
    end
  end

  defp estimate_fees do
    case Ethereumex.HttpClient.eth_max_priority_fee_per_gas() do
      {:ok, hex_priority_fee} ->
        priority_fee = hex_to_int(hex_priority_fee)

        case Ethereumex.HttpClient.eth_get_block_by_number("latest", false) do
          {:ok, %{"baseFeePerGas" => hex_base_fee}} ->
            base_fee = hex_to_int(hex_base_fee)
            max_fee = base_fee * 2 + priority_fee
            {:ok, %{max_fee_per_gas: max_fee, max_priority_fee_per_gas: priority_fee}}

          _ ->
            fallback_gas_price()
        end

      _ ->
        fallback_gas_price()
    end
  end

  defp fallback_gas_price do
    case Ethereumex.HttpClient.eth_gas_price() do
      {:ok, hex_price} ->
        price = hex_to_int(hex_price)
        {:ok, %{gas_price: price}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp hex_to_int("0x" <> hex), do: String.to_integer(hex, 16)
  defp hex_to_int(hex) when is_binary(hex), do: String.to_integer(hex, 16)
  defp hex_to_int(int) when is_integer(int), do: int

  defp get_current_chain_id do
    case Ethereumex.HttpClient.eth_chain_id() do
      {:ok, hex} -> hex_to_int(hex)
      _ -> 1
    end
  end

  defp exceeds_fee_cap?(tx_params) do
    default_cap = 500_000_000_000 # 500 Gwei
    cap = tx_params[:max_fee_cap] || default_cap

    max_fee = tx_params[:max_fee_per_gas] || tx_params[:gas_price]

    if max_fee && max_fee > cap do
      true
    else
      case estimate_fees() do
        {:ok, %{max_fee_per_gas: est_max}} -> est_max > cap
        {:ok, %{gas_price: est_price}} -> est_price > cap
        _ -> false
      end
    end
  end

  defp dry_run_tx(params, state) do
    ethers_tx = %{to: params[:to], data: params[:data] || ""}
    opts = [from: state.address, value: params[:value] || 0]

    case Ethers.estimate_gas(ethers_tx, opts) do
      {:ok, gas} -> {:ok, gas}
      {:error, reason} -> {:error, reason}
      _ -> {:error, "Unknown estimation error"}
    end
  end
end
