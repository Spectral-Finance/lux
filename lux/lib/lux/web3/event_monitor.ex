defmodule Lux.Web3.EventMonitor do
  @moduledoc """
  A real-time smart-contract event monitoring and subscription system.
  """
  use GenServer
  require Logger

  alias Lux.Prisms.MultiChainRpcPrism

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def subscribe(contract_address, event_signature, chain, filters \\ %{}) do
    GenServer.call(__MODULE__, {:subscribe, contract_address, event_signature, chain, filters})
  end

  def unsubscribe(contract_address) do
    GenServer.call(__MODULE__, {:unsubscribe, contract_address})
  end

  def sync_historical(contract_address, event_signature, chain, from_block, to_block) do
    GenServer.call(__MODULE__, {:sync_historical, contract_address, event_signature, chain, from_block, to_block})
  end

  def add_webhook(url) do
    GenServer.call(__MODULE__, {:add_webhook, url})
  end

  def get_persisted_events(contract_address \\ nil) do
    GenServer.call(__MODULE__, {:get_events, contract_address})
  end

  def replay_events(contract_address \\ nil) do
    GenServer.call(__MODULE__, {:replay, contract_address})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    poll_interval = Keyword.get(opts, :poll_interval, 5000)
    state = %{
      subscriptions: %{},
      webhooks: [],
      events: [],
      poll_interval: poll_interval,
      timer: nil
    }

    # Schedule first poll tick
    timer = if poll_interval > 0, do: schedule_poll(poll_interval), else: nil
    {:ok, %{state | timer: timer}}
  end

  @impl true
  def handle_call({:subscribe, contract, event, chain, filters}, _from, state) do
    # Fetch current block to start polling from
    start_block =
      case get_latest_block(chain) do
        {:ok, num} -> num
        _ -> 0
      end

    new_sub = %{
      contract: contract,
      event: event,
      chain: chain,
      filters: filters,
      last_block: start_block
    }

    new_subs = Map.put(state.subscriptions, contract, new_sub)
    Logger.info("Subscribed to event #{event} on contract #{contract} (chain: #{chain}, start block: #{start_block})")
    {:reply, :ok, %{state | subscriptions: new_subs}}
  end

  def handle_call({:unsubscribe, contract}, _from, state) do
    new_subs = Map.delete(state.subscriptions, contract)
    Logger.info("Unsubscribed from contract #{contract}")
    {:reply, :ok, %{state | subscriptions: new_subs}}
  end

  def handle_call({:sync_historical, contract, event, chain, from, to}, _from, state) do
    Logger.info("Syncing historical events for #{event} on #{contract} from block #{from} to #{to}")

    case fetch_logs(contract, event, chain, from, to) do
      {:ok, logs} ->
        processed = process_logs(logs, contract, event, state.webhooks)
        new_events = Enum.uniq_by(state.events ++ processed, fn e -> {e.tx_hash, e.log_index} end)
        {:reply, {:ok, processed}, %{state | events: new_events}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:add_webhook, url}, _from, state) do
    Logger.info("Added webhook: #{url}")
    {:reply, :ok, %{state | webhooks: Enum.uniq([url | state.webhooks])}}
  end

  def handle_call({:get_events, nil}, _from, state) do
    {:reply, state.events, state}
  end

  def handle_call({:get_events, contract}, _from, state) do
    filtered_events = Enum.filter(state.events, fn e -> e.contract == contract end)
    {:reply, filtered_events, state}
  end

  def handle_call({:replay, contract}, _from, state) do
    events_to_replay =
      if contract == nil do
        state.events
      else
        Enum.filter(state.events, fn e -> e.contract == contract end)
      end

    Enum.each(events_to_replay, fn event ->
      dispatch_webhooks(event, state.webhooks)
    end)

    {:reply, {:ok, length(events_to_replay)}, state}
  end

  @impl true
  def handle_info(:poll, state) do
    # Perform poll for all subscriptions
    new_subs =
      Map.new(state.subscriptions, fn {contract, sub} ->
        case poll_subscription(sub, state.webhooks) do
          {:ok, new_sub, processed_events} ->
            send(self(), {:accumulate_events, processed_events})
            {contract, new_sub}

          _ ->
            {contract, sub}
        end
      end)

    timer = schedule_poll(state.poll_interval)
    {:noreply, %{state | subscriptions: new_subs, timer: timer}}
  end

  def handle_info({:accumulate_events, new_events}, state) do
    {:noreply, %{state | events: Enum.uniq_by(state.events ++ new_events, fn e -> {e.tx_hash, e.log_index} end)}}
  end

  # Helper Functions

  defp schedule_poll(interval) do
    Process.send_after(self(), :poll, interval)
  end

  defp poll_subscription(sub, webhooks) do
    case get_latest_block(sub.chain) do
      {:ok, latest} when latest > sub.last_block ->
        from = sub.last_block + 1
        to = latest

        case fetch_logs(sub.contract, sub.event, sub.chain, from, to) do
          {:ok, logs} ->
            processed = process_logs(logs, sub.contract, sub.event, webhooks)
            {:ok, %{sub | last_block: latest}, processed}

          {:error, _reason} ->
            {:error, sub}
        end

      _ ->
        {:ok, sub, []}
    end
  end

  defp get_latest_block(chain) do
    case MultiChainRpcPrism.handler(%{chain: chain, method: "eth_blockNumber", params: []}, %{}) do
      {:ok, %{result: hex_num}} when is_binary(hex_num) ->
        case String.slice(hex_num, 0, 2) do
          "0x" -> {:ok, String.slice(hex_num, 2..-1) |> String.to_integer(16)}
          _ -> {:ok, String.to_integer(hex_num)}
        end

      {:ok, %{result: num}} when is_integer(num) ->
        {:ok, num}

      _ ->
        {:error, "failed to get block number"}
    end
  end

  defp fetch_logs(contract, event_sig, chain, from, to) do
    from_hex = "0x" <> Integer.to_string(from, 16)
    to_hex = "0x" <> Integer.to_string(to, 16)

    # Calculate topic from event signature
    topic = "0x" <> (ExKeccak.hash_256(event_sig) |> Base.encode16(case: :lower))

    filter = %{
      address: contract,
      fromBlock: from_hex,
      toBlock: to_hex,
      topics: [topic]
    }

    case MultiChainRpcPrism.handler(%{chain: chain, method: "eth_getLogs", params: [filter]}, %{}) do
      {:ok, %{result: logs}} when is_list(logs) -> {:ok, logs}
      {:error, reason} -> {:error, reason}
      _ -> {:error, "malformed response"}
    end
  end

  defp process_logs(logs, contract, event, webhooks) do
    Enum.map(logs, fn log ->
      parsed_event = %{
        contract: contract,
        event: event,
        block_number: Map.get(log, "blockNumber"),
        tx_hash: Map.get(log, "transactionHash"),
        log_index: Map.get(log, "logIndex"),
        data: Map.get(log, "data"),
        topics: Map.get(log, "topics")
      }

      dispatch_webhooks(parsed_event, webhooks)
      parsed_event
    end)
  end

  defp dispatch_webhooks(event, webhooks) do
    Enum.each(webhooks, fn url ->
      spawn(fn ->
        Req.post(url, json: event)
      end)
    end)
  end
end
