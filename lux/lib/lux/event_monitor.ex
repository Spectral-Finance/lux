defmodule Lux.EventMonitor do
  @moduledoc """
  Core GenServer for managing smart contract event monitoring.

  The EventMonitor coordinates event subscriptions, polling, decoding,
  filtering, storage, and webhook notifications. It serves as the central
  orchestration point for the event monitoring system.

  ## Architecture

  ```
  ┌─────────────────────────────────────────────────────┐
  │                   EventMonitor                       │
  │                                                      │
  │  ┌─────────────┐  ┌──────────┐  ┌───────────────┐  │
  │  │ Subscriptions│  │  Decoder  │  │    Filter     │  │
  │  └──────┬───────┘  └────┬─────┘  └──────┬────────┘  │
  │         │               │               │            │
  │  ┌──────▼───────────────▼───────────────▼────────┐  │
  │  │              Poll Loop                         │  │
  │  │  fetch logs → decode → filter → store → notify │  │
  │  └───────────────────────────────────────────────-┘  │
  │         │                               │            │
  │  ┌──────▼───────┐            ┌──────────▼─────────┐ │
  │  │    Store      │            │     Webhook        │ │
  │  │   (ETS)       │            │    Manager         │ │
  │  └───────────────┘            └────────────────────┘ │
  └─────────────────────────────────────────────────────┘
  ```

  ## Usage

      # Start the monitor
      {:ok, pid} = Lux.EventMonitor.start_link()

      # Subscribe to Transfer events on USDC
      {:ok, sub_id} = Lux.EventMonitor.subscribe(%{
        address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        chain_id: 1,
        event_names: ["Transfer"],
        abi: usdc_abi
      })

      # Register a webhook for notifications
      {:ok, wh_id} = Lux.EventMonitor.register_webhook(%{
        url: "https://api.example.com/events",
        filter: %{event_name: "Transfer"}
      })

      # Query stored events
      {:ok, events} = Lux.EventMonitor.query_events(%{
        address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        event_name: "Transfer",
        limit: 50
      })

  ## Multi-Chain Support

  The monitor supports subscriptions across multiple chains simultaneously.
  Each subscription specifies its chain_id and events are tracked per-chain.

  Supported chains (via Etherscan API):
  - Ethereum (1)
  - Polygon (137)
  - BSC (56)
  - Arbitrum (42161)
  - Optimism (10)
  - Base (8453)
  - And any chain supported by Etherscan V2 API
  """

  use GenServer

  alias Lux.EventMonitor.Decoder
  alias Lux.EventMonitor.EventLog
  alias Lux.EventMonitor.Filter
  alias Lux.EventMonitor.Store
  alias Lux.EventMonitor.Subscription
  alias Lux.EventMonitor.Webhook

  require Logger

  @type state :: %{
          subscriptions: %{String.t() => Subscription.t()},
          decoders: %{String.t() => Decoder.t()},
          store: GenServer.server(),
          webhook: GenServer.server(),
          poll_timers: %{String.t() => reference()},
          event_callbacks: [function()],
          log_fetcher: module() | nil
        }

  # Client API

  @doc """
  Starts the EventMonitor.

  ## Options

    * `:name` - Registered name (default: `__MODULE__`)
    * `:store` - Event store process (default: `Lux.EventMonitor.Store`)
    * `:webhook` - Webhook manager process (default: `Lux.EventMonitor.Webhook`)
    * `:log_fetcher` - Module that implements log fetching (for testing)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Creates a new event subscription.

  ## Parameters

    * `config` - Subscription configuration map containing:
      * `:address` (required) - Contract address
      * `:chain_id` (required) - Chain identifier
      * `:abi` - Contract ABI for event decoding
      * `:event_names` - List of event names to monitor
      * `:from_block` - Starting block number
      * `:poll_interval_ms` - Polling interval (default: 15,000ms)

  ## Returns

  `{:ok, subscription_id}` on success.
  """
  @spec subscribe(GenServer.server(), map()) :: {:ok, String.t()}
  def subscribe(server \\ __MODULE__, config) do
    GenServer.call(server, {:subscribe, config})
  end

  @doc """
  Removes an event subscription and stops its polling.
  """
  @spec unsubscribe(GenServer.server(), String.t()) :: :ok | {:error, :not_found}
  def unsubscribe(server \\ __MODULE__, subscription_id) do
    GenServer.call(server, {:unsubscribe, subscription_id})
  end

  @doc """
  Lists all active subscriptions.
  """
  @spec list_subscriptions(GenServer.server()) :: [Subscription.t()]
  def list_subscriptions(server \\ __MODULE__) do
    GenServer.call(server, :list_subscriptions)
  end

  @doc """
  Gets a subscription by ID.
  """
  @spec get_subscription(GenServer.server(), String.t()) :: {:ok, Subscription.t()} | {:error, :not_found}
  def get_subscription(server \\ __MODULE__, subscription_id) do
    GenServer.call(server, {:get_subscription, subscription_id})
  end

  @doc """
  Registers a webhook for event notifications.
  """
  @spec register_webhook(GenServer.server(), map()) :: {:ok, String.t()}
  def register_webhook(server \\ __MODULE__, config) do
    GenServer.call(server, {:register_webhook, config})
  end

  @doc """
  Unregisters a webhook.
  """
  @spec unregister_webhook(GenServer.server(), String.t()) :: :ok | {:error, :not_found}
  def unregister_webhook(server \\ __MODULE__, webhook_id) do
    GenServer.call(server, {:unregister_webhook, webhook_id})
  end

  @doc """
  Queries stored events.
  """
  @spec query_events(GenServer.server(), map()) :: {:ok, [EventLog.t()]}
  def query_events(server \\ __MODULE__, query) do
    GenServer.call(server, {:query_events, query})
  end

  @doc """
  Registers a callback function that will be invoked for each new event.

  The callback receives an EventLog struct as its only argument.
  """
  @spec on_event(GenServer.server(), (EventLog.t() -> any())) :: :ok
  def on_event(server \\ __MODULE__, callback) when is_function(callback, 1) do
    GenServer.call(server, {:on_event, callback})
  end

  @doc """
  Manually triggers a poll for a specific subscription.
  Useful for testing or catching up on missed events.
  """
  @spec poll_now(GenServer.server(), String.t()) :: {:ok, [EventLog.t()]} | {:error, any()}
  def poll_now(server \\ __MODULE__, subscription_id) do
    GenServer.call(server, {:poll_now, subscription_id}, 30_000)
  end

  @doc """
  Returns monitoring statistics.
  """
  @spec stats(GenServer.server()) :: map()
  def stats(server \\ __MODULE__) do
    GenServer.call(server, :stats)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    state = %{
      subscriptions: %{},
      decoders: %{},
      store: Keyword.get(opts, :store, Lux.EventMonitor.Store),
      webhook: Keyword.get(opts, :webhook, Lux.EventMonitor.Webhook),
      poll_timers: %{},
      event_callbacks: [],
      log_fetcher: Keyword.get(opts, :log_fetcher)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:subscribe, config}, _from, state) do
    subscription = Subscription.new(config)

    # Build decoder if ABI is provided
    decoder =
      if subscription.abi do
        Decoder.new(subscription.abi)
      else
        nil
      end

    # Start polling timer
    timer = schedule_poll(subscription)

    state = %{
      state
      | subscriptions: Map.put(state.subscriptions, subscription.id, subscription),
        decoders: if(decoder, do: Map.put(state.decoders, subscription.id, decoder), else: state.decoders),
        poll_timers: Map.put(state.poll_timers, subscription.id, timer)
    }

    Logger.info("EventMonitor: Subscribed to #{subscription.address} on chain #{subscription.chain_id} (#{subscription.id})")

    {:reply, {:ok, subscription.id}, state}
  end

  def handle_call({:unsubscribe, sub_id}, _from, state) do
    case Map.get(state.subscriptions, sub_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      _sub ->
        # Cancel timer
        case Map.get(state.poll_timers, sub_id) do
          nil -> :ok
          timer -> Process.cancel_timer(timer)
        end

        state = %{
          state
          | subscriptions: Map.delete(state.subscriptions, sub_id),
            decoders: Map.delete(state.decoders, sub_id),
            poll_timers: Map.delete(state.poll_timers, sub_id)
        }

        Logger.info("EventMonitor: Unsubscribed #{sub_id}")
        {:reply, :ok, state}
    end
  end

  def handle_call(:list_subscriptions, _from, state) do
    subs = Map.values(state.subscriptions)
    {:reply, subs, state}
  end

  def handle_call({:get_subscription, sub_id}, _from, state) do
    case Map.get(state.subscriptions, sub_id) do
      nil -> {:reply, {:error, :not_found}, state}
      sub -> {:reply, {:ok, sub}, state}
    end
  end

  def handle_call({:register_webhook, config}, _from, state) do
    result = Webhook.register(state.webhook, config)
    {:reply, result, state}
  end

  def handle_call({:unregister_webhook, webhook_id}, _from, state) do
    result = Webhook.unregister(state.webhook, webhook_id)
    {:reply, result, state}
  end

  def handle_call({:query_events, query}, _from, state) do
    result = Store.query(state.store, query)
    {:reply, result, state}
  end

  def handle_call({:on_event, callback}, _from, state) do
    {:reply, :ok, %{state | event_callbacks: [callback | state.event_callbacks]}}
  end

  def handle_call({:poll_now, sub_id}, _from, state) do
    case Map.get(state.subscriptions, sub_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      subscription ->
        {events, state} = do_poll(subscription, state)
        {:reply, {:ok, events}, state}
    end
  end

  def handle_call(:stats, _from, state) do
    event_count = Store.count(state.store)
    webhooks = Webhook.list(state.webhook)

    stats = %{
      subscription_count: map_size(state.subscriptions),
      active_subscriptions: state.subscriptions |> Map.values() |> Enum.count(& &1.active),
      stored_events: event_count,
      webhook_count: length(webhooks),
      callback_count: length(state.event_callbacks)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info({:poll, sub_id}, state) do
    state =
      case Map.get(state.subscriptions, sub_id) do
        nil ->
          state

        subscription ->
          if subscription.active do
            {_events, state} = do_poll(subscription, state)
            # Reschedule polling
            timer = schedule_poll(subscription)
            %{state | poll_timers: Map.put(state.poll_timers, sub_id, timer)}
          else
            state
          end
      end

    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Internal Implementation

  defp schedule_poll(%Subscription{id: sub_id, poll_interval_ms: interval}) do
    Process.send_after(self(), {:poll, sub_id}, interval)
  end

  defp do_poll(subscription, state) do
    from_block = Subscription.next_poll_from(subscription)

    case fetch_logs(state, subscription, from_block) do
      {:ok, raw_logs, to_block} ->
        # Parse raw logs into EventLog structs
        event_logs =
          raw_logs
          |> Enum.map(&EventLog.from_raw(&1, chain_id: subscription.chain_id))

        # Decode events if decoder is available
        event_logs =
          case Map.get(state.decoders, subscription.id) do
            nil -> event_logs
            decoder -> Decoder.decode_logs(decoder, event_logs)
          end

        # Apply subscription filter if present
        event_logs =
          if subscription.filter do
            Filter.filter_logs(event_logs, subscription.filter)
          else
            event_logs
          end

        # Filter by event names if specified
        event_logs =
          if subscription.event_names != [] do
            Enum.filter(event_logs, fn log ->
              log.event_name in subscription.event_names
            end)
          else
            event_logs
          end

        # Store events
        if length(event_logs) > 0 do
          Store.insert_batch(state.store, event_logs)
        end

        # Notify webhooks
        if length(event_logs) > 0 do
          Webhook.notify_batch(state.webhook, event_logs)
        end

        # Invoke callbacks
        Enum.each(event_logs, fn event_log ->
          Enum.each(state.event_callbacks, fn callback ->
            try do
              callback.(event_log)
            rescue
              e -> Logger.error("EventMonitor callback error: #{inspect(e)}")
            end
          end)
        end)

        # Update subscription's last synced block
        actual_to_block = to_block || max_block(event_logs, from_block)
        updated_sub = Subscription.update_last_synced(subscription, actual_to_block)

        state = %{
          state
          | subscriptions: Map.put(state.subscriptions, subscription.id, updated_sub)
        }

        if length(event_logs) > 0 do
          Logger.debug(
            "EventMonitor: Polled #{length(event_logs)} events for #{subscription.id} " <>
              "(blocks #{from_block}..#{actual_to_block})"
          )
        end

        {event_logs, state}

      {:error, reason} ->
        Logger.warning("EventMonitor: Poll failed for #{subscription.id}: #{inspect(reason)}")
        {[], state}
    end
  end

  defp fetch_logs(state, subscription, from_block) do
    if state.log_fetcher do
      state.log_fetcher.fetch_logs(subscription, from_block)
    else
      fetch_logs_via_etherscan(subscription, from_block)
    end
  end

  defp fetch_logs_via_etherscan(subscription, from_block) do
    # Use the Etherscan GetLogs lens to fetch event logs
    params = %{
      address: subscription.address,
      fromBlock: from_block,
      toBlock: 99_999_999,
      chainid: subscription.chain_id,
      page: 1,
      offset: 1000
    }

    # Add topic filters if specified
    params =
      if subscription.topics do
        subscription.topics
        |> Enum.with_index()
        |> Enum.reduce(params, fn
          {nil, _idx}, acc -> acc
          {topic, idx}, acc -> Map.put(acc, String.to_atom("topic#{idx}"), topic)
        end)
      else
        params
      end

    case Lux.Lenses.Etherscan.GetLogs.focus(params) do
      {:ok, %{result: logs}} ->
        max_block =
          logs
          |> Enum.map(&(&1[:block_number] || &1["blockNumber"] || 0))
          |> Enum.map(&parse_block_number/1)
          |> Enum.max(fn -> from_block end)

        # Convert atom-key maps back to string-key maps for EventLog.from_raw
        raw_logs =
          Enum.map(logs, fn log ->
            %{
              "address" => Map.get(log, :address, Map.get(log, "address", "")),
              "topics" => Map.get(log, :topics, Map.get(log, "topics", [])),
              "data" => Map.get(log, :data, Map.get(log, "data", "0x")),
              "blockNumber" => Map.get(log, :block_number, Map.get(log, "blockNumber", "0")),
              "transactionHash" => Map.get(log, :transaction_hash, Map.get(log, "transactionHash", "")),
              "logIndex" => Map.get(log, :log_index, Map.get(log, "logIndex", "0")),
              "timeStamp" => Map.get(log, :timestamp, Map.get(log, "timeStamp")),
              "gasPrice" => Map.get(log, :gas_price, Map.get(log, "gasPrice")),
              "gasUsed" => Map.get(log, :gas_used, Map.get(log, "gasUsed")),
              "transactionIndex" => Map.get(log, :transaction_index, Map.get(log, "transactionIndex")),
              "removed" => Map.get(log, :removed, false)
            }
          end)

        {:ok, raw_logs, max_block}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp max_block(event_logs, default) do
    case event_logs do
      [] -> default
      logs -> Enum.max_by(logs, & &1.block_number).block_number
    end
  end

  defp parse_block_number(val) when is_integer(val), do: val
  defp parse_block_number("0x" <> hex) do
    {val, _} = Integer.parse(hex, 16)
    val
  end
  defp parse_block_number(val) when is_binary(val) do
    case Integer.parse(val) do
      {num, _} -> num
      :error -> 0
    end
  end
  defp parse_block_number(_), do: 0
end
