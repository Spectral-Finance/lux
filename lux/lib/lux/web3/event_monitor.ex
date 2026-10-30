defmodule Lux.Web3.EventMonitor do
  @moduledoc """
  Multi-contract, multi-chain Smart Contract Event Monitoring System for Lux.
  Features:
  - Real-time event polling and historical syncing
  - Multi-contract subscription registry
  - Pattern matching & topic filters
  - Event deduplication and replay via EventStore
  - Webhook dispatch with retry mechanism
  """
  use GenServer
  require Logger

  alias Lux.Web3.EventMonitor.{EventStore, WebhookNotifier}

  @default_poll_interval 4_000
  @default_confirmations 2
  @max_batch_block_range 2_000

  defstruct [
    :rpc_url,
    :chain_id,
    :poll_interval,
    :confirmations,
    subscriptions: %{},
    timer: nil
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def subscribe(server \\ __MODULE__, subscription) do
    GenServer.call(server, {:subscribe, subscription})
  end

  def unsubscribe(server \\ __MODULE__, contract_address) do
    GenServer.call(server, {:unsubscribe, contract_address})
  end

  def sync_historical(server \\ __MODULE__, contract_address, from_block, to_block) do
    GenServer.call(server, {:sync_historical, contract_address, from_block, to_block}, 30_000)
  end

  def status(server \\ __MODULE__) do
    GenServer.call(server, :status)
  end

  @impl true
  def init(opts) do
    case Process.whereis(EventStore) do
      nil -> EventStore.start_link([])
      _pid -> :ok
    end

    state = %__MODULE__{
      rpc_url: Keyword.get(opts, :rpc_url, System.get_env("ETH_RPC_URL", "https://polygon-bor-rpc.publicnode.com")),
      chain_id: Keyword.get(opts, :chain_id, 137),
      poll_interval: Keyword.get(opts, :poll_interval, @default_poll_interval),
      confirmations: Keyword.get(opts, :confirmations, @default_confirmations),
      subscriptions: %{}
    }

    timer = schedule_poll(state.poll_interval)
    {:ok, %{state | timer: timer}}
  end

  @impl true
  def handle_call({:subscribe, sub}, _from, state) do
    address = String.downcase(sub[:address] || "")
    if address == "" do
      {:reply, {:error, :invalid_contract_address}, state}
    else
      sub_record = %{
        address: address,
        topics: sub[:topics] || [],
        webhook_url: sub[:webhook_url],
        from_block: sub[:from_block] || :latest,
        filter_fn: sub[:filter_fn]
      }
      new_subs = Map.put(state.subscriptions, address, sub_record)
      Logger.info("[Lux.EventMonitor] Subscribed contract: #{address}")
      {:reply, {:ok, address}, %{state | subscriptions: new_subs}}
    end
  end

  @impl true
  def handle_call({:unsubscribe, address}, _from, state) do
    clean_addr = String.downcase(address)
    new_subs = Map.delete(state.subscriptions, clean_addr)
    {:reply, :ok, %{state | subscriptions: new_subs}}
  end

  @impl true
  def handle_call({:sync_historical, address, from_b, to_b}, _from, state) do
    res = perform_historical_sync(state, address, from_b, to_b)
    {:reply, res, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, %{
      rpc_url: state.rpc_url,
      chain_id: state.chain_id,
      subscriptions_count: map_size(state.subscriptions),
      subscriptions: state.subscriptions
    }, state}
  end

  @impl true
  def handle_info(:poll_events, state) do
    new_state = poll_subscribed_contracts(state)
    timer = schedule_poll(state.poll_interval)
    {:noreply, %{new_state | timer: timer}}
  end

  defp schedule_poll(interval) do
    Process.send_after(self(), :poll_events, interval)
  end

  defp poll_subscribed_contracts(state) do
    Enum.reduce(state.subscriptions, state, fn {address, sub}, acc ->
      latest_block = get_latest_block_number(acc.rpc_url)
      confirmed_block = max(latest_block - acc.confirmations, 0)
      
      meta_key = "#{acc.chain_id}:#{address}"
      last_synced = EventStore.get_last_synced_block(meta_key, confirmed_block - 1)

      if confirmed_block > last_synced do
        from_block = last_synced + 1
        to_block = min(confirmed_block, from_block + @max_batch_block_range)
        
        fetch_and_process_logs(acc, sub, from_block, to_block)
        EventStore.set_last_synced_block(meta_key, to_block)
      end

      acc
    end)
  end

  defp perform_historical_sync(state, address, from_block, to_block) do
    clean_addr = String.downcase(address)
    sub = Map.get(state.subscriptions, clean_addr, %{address: clean_addr, topics: []})
    
    chunks = Stream.iterate(from_block, &(&1 + @max_batch_block_range))
             |> Stream.take_while(&(&1 <= to_block))
             |> Enum.map(fn start_b ->
               end_b = min(start_b + @max_batch_block_range - 1, to_block)
               {start_b, end_b}
             end)

    total_events = Enum.reduce(chunks, 0, fn {s, e}, count ->
      events = fetch_and_process_logs(state, sub, s, e)
      count + length(events)
    end)

    {:ok, %{synced_from: from_block, synced_to: to_block, total_events: total_events}}
  end

  defp fetch_and_process_logs(state, sub, from_block, to_block) do
    payload = %{
      jsonrpc: "2.0",
      id: 1,
      method: "eth_getLogs",
      params: [%{
        address: sub.address,
        fromBlock: "0x" <> Integer.to_string(from_block, 16),
        toBlock: "0x" <> Integer.to_string(to_block, 16),
        topics: sub[:topics] || []
      }]
    }

    case Req.post(state.rpc_url, json: payload) do
      {:ok, %{status: 200, body: %{"result" => logs}}} when is_list(logs) ->
        logs
        |> Enum.map(&format_log(&1, state.chain_id))
        |> Enum.filter(&apply_subscription_filter(&1, sub))
        |> Enum.map(&persist_and_dispatch(&1, sub))

      _error ->
        []
    end
  end

  defp format_log(log, chain_id) do
    %{
      chain_id: chain_id,
      address: log["address"],
      block_number: hex_to_int(log["blockNumber"]),
      transaction_hash: log["transactionHash"],
      log_index: hex_to_int(log["logIndex"]),
      topics: log["topics"] || [],
      data: log["data"]
    }
  end

  defp apply_subscription_filter(event, sub) do
    cond do
      is_function(sub[:filter_fn], 1) -> sub[:filter_fn].(event)
      true -> true
    end
  end

  defp persist_and_dispatch(event, sub) do
    case EventStore.save_event(event) do
      {:ok, _id} ->
        if sub[:webhook_url] do
          Task.start(fn -> WebhookNotifier.dispatch(sub.webhook_url, event) end)
        end
        event

      {:duplicate, _id} ->
        event
    end
  end

  defp get_latest_block_number(rpc_url) do
    case Req.post(rpc_url, json: %{jsonrpc: "2.0", id: 1, method: "eth_blockNumber", params: []}) do
      {:ok, %{status: 200, body: %{"result" => hex}}} when is_binary(hex) ->
        hex_to_int(hex)
      _ ->
        0
    end
  end

  defp hex_to_int(nil), do: 0
  defp hex_to_int("0x" <> hex), do: String.to_integer(hex, 16)
  defp hex_to_int(num) when is_integer(num), do: num
  defp hex_to_int(_), do: 0
end
