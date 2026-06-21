defmodule Lux.Web3.EventMonitor do
  @moduledoc """
  GenServer that monitors smart contract events across multiple contracts and chains.

  Provides:
    - Contract event subscription management
    - Real-time event monitoring via periodic `eth_getLogs` polling
    - Historical event syncing from a specified block range
    - Webhook notifications for matched events
    - Event persistence and replay from an in-memory store
    - Custom event filtering and pattern matching via `Lux.Web3.EventFilter`

  ## Usage

      # Start the monitor
      {:ok, pid} = Lux.Web3.EventMonitor.start_link()

      # Subscribe to Transfer events on USDT
      Lux.Web3.EventMonitor.subscribe(%{
        id: "usdt-transfers",
        contract_address: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
        event_signatures: ["Transfer(address,address,uint256)"],
        chain_id: 1,
        callback: fn event -> IO.inspect(event) end
      })

      # Query stored events
      {:ok, events} = Lux.Web3.EventMonitor.get_events("usdt-transfers")
  """

  use GenServer
  require Logger

  alias Lux.Web3.EventFilter

  @default_poll_interval_ms 15_000
  @max_stored_events 10_000
  @max_block_range 2_000

  # ── Public API ──────────────────────────────────────────────────────

  @doc """
  Starts the EventMonitor GenServer.

  ## Options
    * `:poll_interval` – polling interval in milliseconds (default: 15_000)
    * `:rpc_urls` – map of chain_id => rpc_url
    * `:name` – process name (default: `__MODULE__`)
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Subscribes to contract events matching the given specification.

  ## Subscription map keys
    * `:id` – unique subscription identifier (required)
    * `:contract_address` – contract address to monitor (required)
    * `:event_signatures` – list of event signature strings (e.g. `["Transfer(address,address,uint256)"]`)
    * `:chain_id` – EVM chain ID (default: 1)
    * `:callback` – function to call on new events `(decoded_event -> any)`
    * `:webhook_url` – URL to POST event notifications to
    * `:from_block` – block to start monitoring from (default: "latest")
    * `:topics` – additional topic filters
  """
  @spec subscribe(map(), GenServer.server()) :: :ok | {:error, String.t()}
  def subscribe(subscription, server \\ __MODULE__) do
    case validate_subscription(subscription) do
      :ok -> GenServer.call(server, {:subscribe, subscription})
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Removes a subscription by ID.
  """
  @spec unsubscribe(String.t(), GenServer.server()) :: :ok
  def unsubscribe(subscription_id, server \\ __MODULE__) do
    GenServer.call(server, {:unsubscribe, subscription_id})
  end

  @doc """
  Returns all stored events for a subscription.
  """
  @spec get_events(String.t(), GenServer.server()) :: {:ok, [map()]} | {:error, :not_found}
  def get_events(subscription_id, server \\ __MODULE__) do
    GenServer.call(server, {:get_events, subscription_id})
  end

  @doc """
  Returns events matching the given filter criteria from a subscription's stored events.

  ## Filter options
    * `:min_block` – minimum block number
    * `:max_block` – maximum block number
    * `:event_signatures` – list of signatures to match
    * `:limit` – maximum number of events to return
  """
  @spec query_events(String.t(), map(), GenServer.server()) ::
          {:ok, [map()]} | {:error, :not_found}
  def query_events(subscription_id, filter \\ %{}, server \\ __MODULE__) do
    GenServer.call(server, {:query_events, subscription_id, filter})
  end

  @doc """
  Fetches historical events for a subscription within a block range.
  """
  @spec sync_historical(String.t(), non_neg_integer(), non_neg_integer(), GenServer.server()) ::
          {:ok, [map()]} | {:error, any()}
  def sync_historical(subscription_id, from_block, to_block, server \\ __MODULE__) do
    GenServer.call(server, {:sync_historical, subscription_id, from_block, to_block}, 60_000)
  end

  @doc """
  Returns the list of active subscriptions.
  """
  @spec list_subscriptions(GenServer.server()) :: [map()]
  def list_subscriptions(server \\ __MODULE__) do
    GenServer.call(server, :list_subscriptions)
  end

  @doc """
  Returns the current status of the monitor (subscription count, event counts, etc.).
  """
  @spec status(GenServer.server()) :: map()
  def status(server \\ __MODULE__) do
    GenServer.call(server, :status)
  end

  # ── GenServer Callbacks ─────────────────────────────────────────────

  @impl true
  def init(opts) do
    poll_interval = Keyword.get(opts, :poll_interval, @default_poll_interval_ms)
    rpc_urls = Keyword.get(opts, :rpc_urls, default_rpc_urls())

    state = %{
      subscriptions: %{},
      events: %{},
      last_block: %{},
      poll_interval: poll_interval,
      rpc_urls: rpc_urls
    }

    schedule_poll(poll_interval)

    {:ok, state}
  end

  @impl true
  def handle_call({:subscribe, sub}, _from, state) do
    id = sub.id
    chain_id = Map.get(sub, :chain_id, 1)
    from_block = Map.get(sub, :from_block, "latest")

    subscription = %{
      id: id,
      contract_address: sub.contract_address,
      event_signatures: Map.get(sub, :event_signatures, []),
      chain_id: chain_id,
      callback: Map.get(sub, :callback),
      webhook_url: Map.get(sub, :webhook_url),
      topics: Map.get(sub, :topics, []),
      created_at: DateTime.utc_now(),
      active: true
    }

    state =
      state
      |> put_in([:subscriptions, id], subscription)
      |> put_in([:events, id], [])
      |> put_in([:last_block, id], from_block)

    Logger.info("EventMonitor: Subscribed #{id} to #{sub.contract_address} on chain #{chain_id}")

    {:reply, :ok, state}
  end

  def handle_call({:unsubscribe, id}, _from, state) do
    state =
      state
      |> update_in([:subscriptions], &Map.delete(&1, id))
      |> update_in([:events], &Map.delete(&1, id))
      |> update_in([:last_block], &Map.delete(&1, id))

    Logger.info("EventMonitor: Unsubscribed #{id}")

    {:reply, :ok, state}
  end

  def handle_call({:get_events, id}, _from, state) do
    case Map.get(state.events, id) do
      nil -> {:reply, {:error, :not_found}, state}
      events -> {:reply, {:ok, Enum.reverse(events)}, state}
    end
  end

  def handle_call({:query_events, id, filter}, _from, state) do
    case Map.get(state.events, id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      events ->
        limit = Map.get(filter, :limit, length(events))

        filtered =
          events
          |> Enum.reverse()
          |> Enum.filter(&EventFilter.matches?(&1, filter))
          |> Enum.take(limit)

        {:reply, {:ok, filtered}, state}
    end
  end

  def handle_call({:sync_historical, id, from_block, to_block}, _from, state) do
    case Map.get(state.subscriptions, id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      sub ->
        case fetch_historical_logs(sub, from_block, to_block, state.rpc_urls) do
          {:ok, new_events} ->
            existing = Map.get(state.events, id, [])

            merged =
              (new_events ++ existing)
              |> Enum.uniq_by(& &1.transaction_hash)
              |> Enum.take(@max_stored_events)

            state = put_in(state, [:events, id], merged)

            {:reply, {:ok, new_events}, state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call(:list_subscriptions, _from, state) do
    subs = state.subscriptions |> Map.values() |> Enum.map(&sanitize_subscription/1)
    {:reply, subs, state}
  end

  def handle_call(:status, _from, state) do
    status = %{
      subscription_count: map_size(state.subscriptions),
      total_events:
        state.events |> Map.values() |> Enum.map(&length/1) |> Enum.sum(),
      subscriptions:
        Enum.map(state.subscriptions, fn {id, _sub} ->
          %{
            id: id,
            event_count: length(Map.get(state.events, id, [])),
            last_block: Map.get(state.last_block, id)
          }
        end),
      poll_interval: state.poll_interval
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info(:poll_events, state) do
    state = poll_all_subscriptions(state)
    schedule_poll(state.poll_interval)
    {:noreply, state}
  end

  def handle_info({:webhook_response, _ref, _result}, state) do
    # Async webhook responses — log and discard
    {:noreply, state}
  end

  # ── Polling Logic ───────────────────────────────────────────────────

  defp poll_all_subscriptions(state) do
    Enum.reduce(state.subscriptions, state, fn {id, sub}, acc ->
      if sub.active do
        poll_subscription(id, sub, acc)
      else
        acc
      end
    end)
  end

  defp poll_subscription(id, sub, state) do
    last_block = Map.get(state.last_block, id, "latest")

    filter_opts = %{
      contract_address: sub.contract_address,
      event_signatures: sub.event_signatures,
      from_block: last_block,
      to_block: "latest",
      topics: sub.topics
    }

    case EventFilter.build_filter(filter_opts) do
      {:ok, filter} ->
        case fetch_logs(filter, sub.chain_id, state.rpc_urls) do
          {:ok, logs} when logs != [] ->
            new_events = EventFilter.decode_logs(logs)
            process_new_events(id, sub, new_events, state)

          {:ok, _empty} ->
            state

          {:error, reason} ->
            Logger.warning("EventMonitor: Failed to fetch logs for #{id}: #{inspect(reason)}")
            state
        end

      {:error, reason} ->
        Logger.warning("EventMonitor: Failed to build filter for #{id}: #{inspect(reason)}")
        state
    end
  end

  defp process_new_events(id, sub, new_events, state) do
    # Store events
    existing = Map.get(state.events, id, [])

    updated =
      (new_events ++ existing)
      |> Enum.take(@max_stored_events)

    state = put_in(state, [:events, id], updated)

    # Update last processed block
    max_block =
      new_events
      |> Enum.map(& &1.block_number)
      |> Enum.max(fn -> nil end)

    state =
      if max_block do
        next_block = "0x" <> Integer.to_string(max_block + 1, 16)
        put_in(state, [:last_block, id], next_block)
      else
        state
      end

    # Invoke callback
    if sub.callback do
      Enum.each(new_events, fn event ->
        try do
          sub.callback.(event)
        rescue
          e ->
            Logger.warning(
              "EventMonitor: Callback error for #{id}: #{inspect(e)}"
            )
        end
      end)
    end

    # Send webhook notifications
    if sub.webhook_url do
      send_webhook(sub.webhook_url, id, new_events)
    end

    Logger.debug("EventMonitor: #{length(new_events)} new event(s) for #{id}")

    state
  end

  # ── Historical Sync ─────────────────────────────────────────────────

  defp fetch_historical_logs(sub, from_block, to_block, rpc_urls) do
    # Chunk into manageable ranges to avoid RPC limits
    chunks = chunk_block_range(from_block, to_block, @max_block_range)

    results =
      Enum.reduce_while(chunks, {:ok, []}, fn {chunk_from, chunk_to}, {:ok, acc} ->
        filter_opts = %{
          contract_address: sub.contract_address,
          event_signatures: sub.event_signatures,
          from_block: chunk_from,
          to_block: chunk_to,
          topics: Map.get(sub, :topics, [])
        }

        case EventFilter.build_filter(filter_opts) do
          {:ok, filter} ->
            case fetch_logs(filter, sub.chain_id, rpc_urls) do
              {:ok, logs} ->
                events = EventFilter.decode_logs(logs)
                {:cont, {:ok, acc ++ events}}

              {:error, reason} ->
                {:halt, {:error, reason}}
            end

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
      end)

    results
  end

  defp chunk_block_range(from, to, max_range) when is_integer(from) and is_integer(to) do
    if to - from <= max_range do
      [{from, to}]
    else
      Stream.unfold(from, fn current ->
        if current > to do
          nil
        else
          chunk_end = min(current + max_range - 1, to)
          {{current, chunk_end}, chunk_end + 1}
        end
      end)
      |> Enum.to_list()
    end
  end

  defp chunk_block_range(from, to, _max_range), do: [{from, to}]

  # ── RPC Communication ──────────────────────────────────────────────

  defp fetch_logs(filter, chain_id, rpc_urls) do
    case get_rpc_url(chain_id, rpc_urls) do
      nil ->
        # Fall back to Ethereumex for chain 1
        if chain_id == 1 do
          fetch_logs_via_ethereumex(filter)
        else
          {:error, :no_rpc_url_configured}
        end

      _url ->
        fetch_logs_via_ethereumex(filter)
    end
  end

  defp fetch_logs_via_ethereumex(filter) do
    case Ethereumex.HttpClient.eth_get_logs(filter) do
      {:ok, logs} -> {:ok, logs}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_rpc_url(chain_id, rpc_urls), do: Map.get(rpc_urls, chain_id)

  # ── Webhook Notification ────────────────────────────────────────────

  defp send_webhook(url, subscription_id, events) do
    payload = %{
      subscription_id: subscription_id,
      event_count: length(events),
      events:
        Enum.map(events, fn e ->
          %{
            event_signature: e.event_signature,
            contract_address: e.contract_address,
            block_number: e.block_number,
            transaction_hash: e.transaction_hash,
            log_index: e.log_index,
            data: e.data,
            removed: e.removed
          }
        end),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # Fire-and-forget async webhook
    Task.start(fn ->
      try do
        Req.post(url, json: payload)
      rescue
        e ->
          Logger.warning(
            "EventMonitor: Webhook delivery failed for #{subscription_id}: #{inspect(e)}"
          )
      end
    end)
  end

  # ── Helpers ─────────────────────────────────────────────────────────

  defp schedule_poll(interval) do
    Process.send_after(self(), :poll_events, interval)
  end

  defp validate_subscription(%{id: id, contract_address: addr})
       when is_binary(id) and is_binary(addr) do
    :ok
  end

  defp validate_subscription(_), do: {:error, "Subscription requires :id and :contract_address"}

  defp sanitize_subscription(sub) do
    Map.drop(sub, [:callback])
  end

  defp default_rpc_urls do
    %{
      1 => System.get_env("ETH_MAINNET_RPC_URL") || "http://localhost:8545",
      137 => System.get_env("POLYGON_RPC_URL"),
      42161 => System.get_env("ARBITRUM_RPC_URL"),
      10 => System.get_env("OPTIMISM_RPC_URL"),
      8453 => System.get_env("BASE_RPC_URL")
    }
  end
end
