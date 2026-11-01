defmodule Lux.Web3.EventMonitor do
  @moduledoc """
  Unified Smart Contract Event Monitoring System for multi-chain EVM networks (#75).

  Coordinates:
  - Real-time and historical contract event tracking
  - Complex pattern filtering and threshold evaluations
  - Standard and custom ABI decoding
  - Webhook alerts with HMAC authentication
  - Event persistence and deterministic replay
  """

  alias Lux.Web3.EventMonitor.Schemas.{MonitoredEvent, Subscription}
  alias Lux.Web3.EventMonitor.{
    SubscriptionManager,
    EventStore,
    Decoder,
    FilterEngine,
    WebhookDispatcher,
    Syncer
  }

  @doc """
  Registers a new smart contract event subscription.
  """
  @spec subscribe(map()) :: {:ok, Subscription.t()} | {:error, term()}
  def subscribe(attrs) when is_map(attrs) do
    # Resolve topic0 if event_signature provided and topic0 missing
    resolved_attrs =
      if is_nil(attrs[:topic0] || attrs["topic0"]) and (attrs[:event_name] || attrs["event_name"]) do
        name = attrs[:event_name] || attrs["event_name"]
        found_t0 =
          Enum.find_value(Decoder.standard_signatures(), fn {t0, {type, _sig, _idx, _unidx}} ->
            if to_string(type) == to_string(name), do: t0, else: nil
          end)

        if found_t0, do: Map.put(attrs, :topic0, found_t0), else: attrs
      else
        attrs
      end

    SubscriptionManager.create_subscription(resolved_attrs)
  end

  @doc """
  Retrieves a subscription by ID.
  """
  @spec get_subscription(String.t()) :: {:ok, Subscription.t()} | {:error, :not_found}
  def get_subscription(id), do: SubscriptionManager.get_subscription(id)

  @doc """
  Lists active or filtered subscriptions.
  """
  @spec list_subscriptions(map()) :: [Subscription.t()]
  def list_subscriptions(filters \\ %{}), do: SubscriptionManager.list_subscriptions(filters)

  @doc """
  Pauses an existing subscription.
  """
  @spec pause(String.t()) :: {:ok, Subscription.t()} | {:error, term()}
  def pause(id), do: SubscriptionManager.pause_subscription(id)

  @doc """
  Resumes a paused subscription.
  """
  @spec resume(String.t()) :: {:ok, Subscription.t()} | {:error, term()}
  def resume(id), do: SubscriptionManager.resume_subscription(id)

  @doc """
  Removes a subscription permanently.
  """
  @spec unsubscribe(String.t()) :: :ok | {:error, :not_found}
  def unsubscribe(id), do: SubscriptionManager.delete_subscription(id)

  @doc """
  Ingests, decodes, and routes a raw event log into the monitoring pipeline.
  Matches active subscriptions, stores the event, and triggers webhooks.
  """
  @spec ingest_log(map(), atom(), non_neg_integer()) :: {:ok, [MonitoredEvent.t()]} | {:error, term()}
  def ingest_log(raw_log, chain, chain_id) when is_map(raw_log) do
    topics = (raw_log[:topics] || raw_log["topics"] || []) |> Enum.map(&String.downcase(to_string(&1)))
    data = raw_log[:data] || raw_log["data"]

    decoded =
      case Decoder.decode(topics, data) do
        {:ok, p} -> p
        _ -> %{}
      end

    contract = String.downcase(to_string(raw_log[:address] || raw_log["address"] || ""))
    tx_hash = String.downcase(to_string(raw_log[:transactionHash] || raw_log["transactionHash"] || ""))
    log_idx = parse_int(raw_log[:logIndex] || raw_log["logIndex"]) || 0
    blk_num = parse_int(raw_log[:blockNumber] || raw_log["blockNumber"]) || 0
    blk_hash = raw_log[:blockHash] || raw_log["blockHash"]

    # Match across subscriptions
    dummy_event = %MonitoredEvent{
      id: "raw",
      subscription_id: "match",
      chain_id: chain_id,
      chain: chain,
      contract_address: contract,
      event_name: decoded[:_event_type],
      event_signature: decoded[:_event_signature],
      block_number: blk_num,
      block_hash: blk_hash,
      tx_hash: tx_hash,
      log_index: log_idx,
      topics: topics,
      data: data,
      decoded_params: decoded,
      timestamp: System.system_time(:second)
    }

    matching_subs = SubscriptionManager.match_event(dummy_event)

    processed_events =
      Enum.map(matching_subs, fn sub ->
        evt_id = "evt_#{chain_id}_#{String.trim_leading(tx_hash, "0x")}_#{log_idx}_#{sub.id}"

        event = %MonitoredEvent{
          dummy_event
          | id: evt_id,
            subscription_id: sub.id,
            event_name: decoded[:_event_type] || sub.event_name,
            event_signature: decoded[:_event_signature] || sub.event_signature
        }

        # Store event
        EventStore.store_event(event)

        # Update last processed block
        SubscriptionManager.update_processed_block(sub.id, blk_num)

        # Dispatch webhook if URL configured
        if sub.webhook_url do
          Task.start(fn ->
            WebhookDispatcher.dispatch(event, sub)
          end)
        end

        event
      end)

    {:ok, processed_events}
  end

  @doc """
  Queries stored events with filtering and pagination.
  """
  @spec query_events(map(), map()) :: {[MonitoredEvent.t()], non_neg_integer()}
  def query_events(filters \\ %{}, pagination \\ %{}) do
    EventStore.query_events(filters, pagination)
  end

  @doc """
  Syncs historical block range for a subscription.
  """
  @spec sync_historical(String.t(), non_neg_integer(), non_neg_integer(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def sync_historical(subscription_id, from_block, to_block, opts \\ []) do
    case SubscriptionManager.get_subscription(subscription_id) do
      {:ok, sub} ->
        opts_with_store = Keyword.put_new(opts, :event_store, EventStore)
        Syncer.sync_historical(sub, from_block, to_block, opts_with_store)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Replays stored events through a custom callback or webhook dispatcher.
  """
  @spec replay(map(), (MonitoredEvent.t() -> any())) :: {:ok, non_neg_integer()}
  def replay(filters \\ %{}, handler_fn) do
    EventStore.replay_events(filters, handler_fn)
  end

  @doc """
  Returns system monitoring metrics.
  """
  @spec metrics() :: map()
  def metrics do
    %{
      total_subscriptions: length(SubscriptionManager.list_subscriptions()),
      total_events_stored: EventStore.count(),
      total_deliveries: length(WebhookDispatcher.list_deliveries())
    }
  end

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val) do
    clean = String.trim_leading(val, "0x")
    case Integer.parse(clean, 16) do
      {num, _} -> num
      _ ->
        case Integer.parse(val, 10) do
          {num, _} -> num
          _ -> nil
        end
    end
  end
  defp parse_int(_), do: nil
end
