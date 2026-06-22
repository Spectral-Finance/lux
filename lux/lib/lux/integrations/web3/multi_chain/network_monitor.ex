defmodule Lux.Integrations.Web3.MultiChain.NetworkMonitor do
  @moduledoc """
  Monitors a single EVM network. 
  Uses WebSockex if a wss:// URL is provided, otherwise falls back to HTTP polling.
  Adds retry logic, transaction monitoring, and historical backfill capabilities.
  """
  use WebSockex
  require Logger

  alias Lux.Integrations.Web3.MultiChain.Storage

  @poll_interval 5_000
  @max_retries 3

  def start_link(%{chain_id: chain_id, rpc_url: "wss://" <> _ = rpc_url}) do
    WebSockex.start_link(
      rpc_url,
      __MODULE__,
      %{chain_id: chain_id, rpc_url: rpc_url, mode: :websocket, retries: 0},
      name: via_tuple(chain_id)
    )
  end

  def start_link(%{chain_id: chain_id, rpc_url: rpc_url}) do
    GenServer.start_link(
      __MODULE__,
      %{chain_id: chain_id, rpc_url: rpc_url, mode: :http, retries: 0, last_block: nil},
      name: via_tuple(chain_id)
    )
  end

  defp via_tuple(chain_id),
    do: {:via, Registry, {Lux.AgentHub, "multi_chain_monitor_#{chain_id}"}}

  # =========================================================
  # WebSocket Implementation
  # =========================================================

  def handle_connect(_conn, %{mode: :websocket} = state) do
    Logger.info("[MultiChain] Connected to WebSocket for chain: #{state.chain_id}")

    # Subscribe to new heads
    req = %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "eth_subscribe",
      "params" => ["newHeads"]
    }

    # Subscribe to pending transactions
    tx_req = %{
      "jsonrpc" => "2.0",
      "id" => 2,
      "method" => "eth_subscribe",
      "params" => ["newPendingTransactions"]
    }

    # Subscribe to logs
    logs_req = %{
      "jsonrpc" => "2.0",
      "id" => 3,
      "method" => "eth_subscribe",
      "params" => ["logs", %{}]
    }

    {:reply,
     [
       {:text, Jason.encode!(req)},
       {:text, Jason.encode!(tx_req)},
       {:text, Jason.encode!(logs_req)}
     ], %{state | retries: 0}}
  end

  def handle_frame({:text, msg}, %{mode: :websocket} = state) do
    case Jason.decode(msg) do
      {:ok,
       %{
         "method" => "eth_subscription",
         "params" => %{"result" => result, "subscription" => _sub_id}
       }} ->
        process_incoming_data(state.chain_id, result)

      _ ->
        :ok
    end

    {:ok, state}
  end

  def handle_disconnect(%{reason: reason}, %{retries: retries} = state) do
    Logger.warning("[MultiChain] WebSocket disconnected for chain #{state.chain_id}: #{inspect(reason)}")

    if retries < @max_retries do
      Process.sleep(1000 * (retries + 1))
      {:reconnect, %{state | retries: retries + 1}}
    else
      Logger.error("[MultiChain] Max retries reached for chain #{state.chain_id}")
      {:close, state}
    end
  end

  # =========================================================
  # HTTP Polling Implementation
  # =========================================================

  def init(%{mode: :http} = state) do
    Logger.info("[MultiChain] Started HTTP Polling for chain: #{state.chain_id}")
    send(self(), :poll)
    {:ok, state}
  end

  def handle_info(:poll, %{mode: :http} = state) do
    state =
      case fetch_latest_block(state.rpc_url) do
        {:ok, %{"number" => hex_num} = block} ->
          process_incoming_data(state.chain_id, block)
          num = String.to_integer(String.replace(hex_num, "0x", ""), 16)
          
          if state.last_block && state.last_block < num - 1 do
            # Historical backfill needed
            backfill_blocks(state.chain_id, state.rpc_url, state.last_block + 1, num - 1)
          end
          %{state | last_block: num, retries: 0}

        _ ->
          if state.retries < @max_retries do
            %{state | retries: state.retries + 1}
          else
            Logger.error("[MultiChain] Max retries reached for HTTP polling on chain #{state.chain_id}")
            state
          end
      end

    schedule_poll()
    {:noreply, state}
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval)
  end

  defp fetch_latest_block(rpc_url) do
    req = %{
      "jsonrpc" => "2.0",
      "method" => "eth_getBlockByNumber",
      "params" => ["latest", true],
      "id" => 1
    }

    case Req.post(rpc_url, json: req) do
      {:ok, %{status: 200, body: %{"result" => block}}} when not is_nil(block) -> {:ok, block}
      _ -> :error
    end
  end

  defp backfill_blocks(chain_id, rpc_url, start_num, end_num) do
    Logger.info("[MultiChain] Backfilling blocks #{start_num} to #{end_num} for chain #{chain_id}")
    Enum.each(start_num..end_num, fn num ->
      hex_num = "0x" <> Integer.to_string(num, 16)
      req = %{
        "jsonrpc" => "2.0",
        "method" => "eth_getBlockByNumber",
        "params" => [hex_num, true],
        "id" => 1
      }
      case Req.post(rpc_url, json: req) do
        {:ok, %{status: 200, body: %{"result" => block}}} when not is_nil(block) ->
          process_incoming_data(chain_id, block)
        _ ->
          :ok
      end
    end)
  end

  # =========================================================
  # Shared Processing
  # =========================================================

  defp process_incoming_data(chain_id, %{"number" => _, "transactions" => txs} = block) when is_list(txs) do
    Storage.insert_block(chain_id, block)
    # Process embedded transactions
    Enum.each(txs, fn tx ->
      if is_map(tx), do: Storage.insert_transaction(chain_id, tx)
    end)
  end

  defp process_incoming_data(chain_id, %{"number" => _} = block) do
    Storage.insert_block(chain_id, block)
  end

  # This matches a raw transaction hash string (e.g. from newPendingTransactions)
  defp process_incoming_data(chain_id, tx_hash) when is_binary(tx_hash) do
    Storage.insert_transaction(chain_id, %{"hash" => tx_hash})
  end

  defp process_incoming_data(chain_id, %{"transactionHash" => _} = log) do
    Storage.insert_event(chain_id, log)
  end

  defp process_incoming_data(_chain_id, _), do: :ok
end
