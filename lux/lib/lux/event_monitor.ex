defmodule Lux.EventMonitor do
  @moduledoc """
  In-process smart contract event monitoring for Lux agents.

  The monitor keeps contract subscriptions, stores processed events, supports
  historical backfills through `Lux.Lenses.Etherscan.GetLogs`, replays stored
  events, and posts matching events to webhooks.
  """

  use GenServer

  alias Lux.Lenses.Etherscan.GetLogs

  @default_recent_limit 10
  @topic_indexes 0..3

  defstruct subscriptions: %{},
            events: %{},
            event_order: [],
            pollers: %{}

  @doc """
  Starts an event monitor.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Creates a contract event subscription.
  """
  def subscribe(attrs), do: subscribe(__MODULE__, attrs)

  def subscribe(server, attrs), do: GenServer.call(server, {:subscribe, attrs})

  @doc """
  Removes a subscription.
  """
  def unsubscribe(subscription_id), do: unsubscribe(__MODULE__, subscription_id)

  def unsubscribe(server, subscription_id), do: GenServer.call(server, {:unsubscribe, subscription_id})

  @doc """
  Returns all subscriptions.
  """
  def list_subscriptions(server \\ __MODULE__), do: GenServer.call(server, :list_subscriptions)

  @doc """
  Returns one subscription.
  """
  def get_subscription(subscription_id), do: get_subscription(__MODULE__, subscription_id)

  def get_subscription(server, subscription_id),
    do: GenServer.call(server, {:get_subscription, subscription_id})

  @doc """
  Processes a single raw contract event against all active subscriptions.
  """
  def process_event(raw_event) when is_map(raw_event), do: process_event(__MODULE__, raw_event, [])

  def process_event(raw_event, opts) when is_map(raw_event) and is_list(opts),
    do: process_event(__MODULE__, raw_event, opts)

  def process_event(server, raw_event) when is_atom(server) or is_pid(server) or is_tuple(server),
    do: process_event(server, raw_event, [])

  def process_event(server, raw_event, opts),
    do: GenServer.call(server, {:process_event, raw_event, opts})

  @doc """
  Backfills a subscription from explicit logs, a fetcher function, or Etherscan.
  """
  def sync_history(subscription_id) when is_binary(subscription_id),
    do: sync_history(__MODULE__, subscription_id, [])

  def sync_history(subscription_id, opts) when is_binary(subscription_id) and is_list(opts),
    do: sync_history(__MODULE__, subscription_id, opts)

  def sync_history(server, subscription_id) when is_atom(server) or is_pid(server) or is_tuple(server),
    do: sync_history(server, subscription_id, [])

  def sync_history(server, subscription_id, opts),
    do: GenServer.call(server, {:sync_history, subscription_id, opts}, :infinity)

  @doc """
  Polls a subscription once from the stored cursor to `:to_block`.
  """
  def poll_once(subscription_id) when is_binary(subscription_id), do: poll_once(__MODULE__, subscription_id, [])

  def poll_once(subscription_id, opts) when is_binary(subscription_id) and is_list(opts),
    do: poll_once(__MODULE__, subscription_id, opts)

  def poll_once(server, subscription_id) when is_atom(server) or is_pid(server) or is_tuple(server),
    do: poll_once(server, subscription_id, [])

  def poll_once(server, subscription_id, opts),
    do: GenServer.call(server, {:poll_once, subscription_id, opts}, :infinity)

  @doc """
  Starts a lightweight polling loop for a subscription.
  """
  def start_polling(subscription_id, opts \\ []) when is_binary(subscription_id),
    do: start_polling(__MODULE__, subscription_id, opts)

  def start_polling(server, subscription_id, opts),
    do: GenServer.call(server, {:start_polling, subscription_id, opts})

  @doc """
  Stops a polling loop.
  """
  def stop_polling(subscription_id), do: stop_polling(__MODULE__, subscription_id)

  def stop_polling(server, subscription_id),
    do: GenServer.call(server, {:stop_polling, subscription_id})

  @doc """
  Returns stored events, optionally filtered by subscription and block range.
  """
  def replay_events(opts \\ []), do: replay_events(__MODULE__, opts)

  def replay_events(server, opts), do: GenServer.call(server, {:replay_events, opts})

  @doc """
  Returns a dashboard-friendly status snapshot.
  """
  def dashboard(server \\ __MODULE__), do: GenServer.call(server, :dashboard)

  @doc """
  Exports monitor state as a serializable map.
  """
  def snapshot(server \\ __MODULE__), do: GenServer.call(server, :snapshot)

  @doc """
  Loads a previous snapshot.
  """
  def restore(snapshot), do: restore(__MODULE__, snapshot)

  def restore(server, snapshot), do: GenServer.call(server, {:restore, snapshot})

  @impl true
  def init(_opts), do: {:ok, %__MODULE__{}}

  @impl true
  def handle_call({:subscribe, attrs}, _from, state) do
    case normalize_subscription(attrs) do
      {:ok, subscription} ->
        state = put_in(state.subscriptions[subscription.id], subscription)
        {:reply, {:ok, subscription}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:unsubscribe, subscription_id}, _from, state) do
    state = %{
      state
      | subscriptions: Map.delete(state.subscriptions, subscription_id),
        pollers: Map.delete(state.pollers, subscription_id)
    }

    {:reply, :ok, state}
  end

  def handle_call(:list_subscriptions, _from, state) do
    subscriptions =
      state.subscriptions
      |> Map.values()
      |> Enum.sort_by(& &1.created_at, DateTime)

    {:reply, subscriptions, state}
  end

  def handle_call({:get_subscription, subscription_id}, _from, state) do
    case Map.fetch(state.subscriptions, subscription_id) do
      {:ok, subscription} -> {:reply, {:ok, subscription}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:process_event, raw_event, opts}, _from, state) do
    {state, matched, events} = process_raw_event(state, raw_event, opts)

    {:reply, {:ok, %{matched: matched, stored: length(events), events: events}}, state}
  end

  def handle_call({:sync_history, subscription_id, opts}, _from, state) do
    with {:ok, subscription} <- fetch_subscription(state, subscription_id),
         {:ok, logs, params} <- fetch_logs(subscription, opts) do
      {state, matched, events} =
        process_raw_events_for_subscription(
          state,
          subscription_id,
          logs,
          Keyword.put_new(opts, :notify, false)
        )

      reply = %{
        subscription_id: subscription_id,
        from_block: params[:fromBlock],
        to_block: params[:toBlock],
        fetched: length(logs),
        matched: matched,
        stored: length(events),
        events: events
      }

      {:reply, {:ok, reply}, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:poll_once, subscription_id, opts}, _from, state) do
    with {:ok, subscription} <- fetch_subscription(state, subscription_id),
         {:ok, opts} <- poll_opts(subscription, opts),
         {:ok, logs, params} <- fetch_logs(subscription, opts) do
      {state, matched, events} =
        process_raw_events_for_subscription(state, subscription_id, logs, opts)

      reply = %{
        subscription_id: subscription_id,
        from_block: params[:fromBlock],
        to_block: params[:toBlock],
        fetched: length(logs),
        matched: matched,
        stored: length(events),
        events: events
      }

      {:reply, {:ok, reply}, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:start_polling, subscription_id, opts}, _from, state) do
    case fetch_subscription(state, subscription_id) do
      {:ok, _subscription} ->
        interval_ms = opts |> fetch(:interval_ms, 15_000) |> parse_int()
        timer = Process.send_after(self(), {:poll_subscription, subscription_id}, interval_ms)
        poller = %{opts: Keyword.put(opts, :interval_ms, interval_ms), timer: timer, status: :running}

        {:reply, {:ok, poller}, put_in(state.pollers[subscription_id], poller)}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:stop_polling, subscription_id}, _from, state) do
    if poller = state.pollers[subscription_id] do
      Process.cancel_timer(poller.timer)
    end

    {:reply, :ok, %{state | pollers: Map.delete(state.pollers, subscription_id)}}
  end

  def handle_call({:replay_events, opts}, _from, state) do
    events = replay_from_state(state, opts)
    {:reply, {:ok, events}, state}
  end

  def handle_call(:dashboard, _from, state) do
    {:reply, dashboard_from_state(state), state}
  end

  def handle_call(:snapshot, _from, state) do
    {:reply, Map.from_struct(state), state}
  end

  def handle_call({:restore, snapshot}, _from, _state) when is_map(snapshot) do
    state = struct(__MODULE__, atomize_known_state(snapshot))
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:poll_subscription, subscription_id}, state) do
    case state.pollers[subscription_id] do
      nil ->
        {:noreply, state}

      %{opts: opts} = poller ->
        {state, _reply} =
          case fetch_subscription(state, subscription_id) do
            {:ok, subscription} ->
              opts = Keyword.put(opts, :to_block, fetch_next_to_block(subscription, opts))

              with {:ok, poll_opts} <- poll_opts(subscription, opts),
                   {:ok, logs, _params} <- fetch_logs(subscription, poll_opts) do
                {new_state, _matched, _events} =
                  process_raw_events_for_subscription(state, subscription_id, logs, poll_opts)
                {new_state, :ok}
              else
                _ -> {state, :error}
              end

            _ ->
              {state, :error}
          end

        interval_ms = fetch(poller.opts, :interval_ms, 15_000)
        timer = Process.send_after(self(), {:poll_subscription, subscription_id}, interval_ms)
        {:noreply, put_in(state.pollers[subscription_id].timer, timer)}
    end
  end

  defp normalize_subscription(attrs) when is_map(attrs) do
    address = attrs |> fetch(:address) |> normalize_address()

    with :ok <- validate_address(address) do
      now = DateTime.utc_now()
      start_block = attrs |> fetch(:start_block, fetch(attrs, :from_block, 0)) |> parse_int()

      subscription = %{
        id: fetch(attrs, :id, Lux.UUID.generate()),
        name: fetch(attrs, :name, "Smart contract event subscription"),
        chain_id: attrs |> fetch(:chain_id, fetch(attrs, :chainid, 1)) |> parse_int(),
        address: address,
        topics: topics_from(attrs),
        filters: fetch(attrs, :filters, %{}),
        event_abi: fetch(attrs, :event_abi),
        decoder: fetch(attrs, :decoder),
        webhook_url: fetch(attrs, :webhook_url),
        start_block: start_block,
        cursor_block: attrs |> fetch(:cursor_block, start_block - 1) |> parse_int(),
        status: :active,
        created_at: now,
        updated_at: now
      }

      {:ok, subscription}
    end
  end

  defp normalize_subscription(_attrs), do: {:error, :invalid_subscription}

  defp process_raw_events_for_subscription(state, subscription_id, raw_events, opts) do
    case fetch_subscription(state, subscription_id) do
      {:ok, subscription} ->
        process_subscription_events(state, subscription, raw_events, opts)

      {:error, _reason} ->
        {state, 0, []}
    end
  end

  defp process_raw_event(state, raw_event, opts) do
    matching =
      state.subscriptions
      |> Map.values()
      |> Enum.filter(&(&1.status == :active and matches_subscription?(&1, raw_event)))

    {state, events} =
      Enum.reduce(matching, {state, []}, fn subscription, {state, events} ->
        {state, event} = store_matching_event(state, subscription, raw_event, opts)
        events = if event, do: events ++ [event], else: events
        {state, events}
      end)

    {state, length(matching), events}
  end

  defp process_subscription_events(state, subscription, raw_events, opts) do
    raw_events
    |> Enum.reduce({state, subscription, 0, []}, fn raw_event, acc ->
      process_subscription_event(raw_event, acc, opts)
    end)
    |> then(fn {state, _subscription, matched, events} -> {state, matched, events} end)
  end

  defp process_subscription_event(raw_event, {state, subscription, matched, events}, opts) do
    if subscription.status == :active and matches_subscription?(subscription, raw_event) do
      {state, event} = store_matching_event(state, subscription, raw_event, opts)
      subscription = Map.fetch!(state.subscriptions, subscription.id)
      {state, subscription, matched + 1, append_event(events, event)}
    else
      {state, subscription, matched, events}
    end
  end

  defp append_event(events, nil), do: events
  defp append_event(events, event), do: events ++ [event]

  defp store_matching_event(state, subscription, raw_event, opts) do
    event = build_event(subscription, raw_event)

    if Map.has_key?(state.events, event.id) do
      {state, nil}
    else
      notification = maybe_deliver_webhook(subscription, event, opts)
      event = Map.put(event, :notification, notification)
      {store_event(state, subscription, event), event}
    end
  end

  defp matches_subscription?(subscription, raw_event) do
    event_address = raw_event |> fetch(:address) |> normalize_address()

    address_matches? =
      is_nil(subscription.address) or is_nil(event_address) or subscription.address == event_address

    address_matches? and topics_match?(subscription.topics, fetch(raw_event, :topics, [])) and
      filters_match?(subscription.filters, raw_event)
  end

  defp topics_match?(subscription_topics, raw_topics) do
    event_topics = Enum.map(List.wrap(raw_topics), &normalize_topic/1)

    subscription_topics
    |> Enum.with_index()
    |> Enum.all?(fn {topic, index} ->
      topic in [nil, ""] or Enum.at(event_topics, index) == normalize_topic(topic)
    end)
  end

  defp filters_match?(filters, raw_event) when is_map(filters) do
    block_number = raw_event |> block_number_from() |> parse_int()
    data = fetch(raw_event, :data, "")
    tx_hash = fetch(raw_event, :transaction_hash, fetch(raw_event, :transactionHash))

    [
      blank?(fetch(filters, :transaction_hash)) or tx_hash == fetch(filters, :transaction_hash),
      blank?(fetch(filters, :data_contains)) or String.contains?(to_string(data), fetch(filters, :data_contains)),
      blank?(fetch(filters, :min_block)) or block_number >= parse_int(fetch(filters, :min_block)),
      blank?(fetch(filters, :max_block)) or block_number <= parse_int(fetch(filters, :max_block))
    ]
    |> Enum.all?()
  end

  defp filters_match?(_filters, _raw_event), do: true

  defp build_event(subscription, raw_event) do
    raw_topics = List.wrap(fetch(raw_event, :topics, []))
    tx_hash = fetch(raw_event, :transaction_hash, fetch(raw_event, :transactionHash, ""))
    log_index = raw_event |> fetch(:log_index, fetch(raw_event, :logIndex, 0)) |> parse_int()
    block_number = raw_event |> block_number_from() |> parse_int()
    event_key = "#{subscription.chain_id}:#{tx_hash}:#{log_index}"

    %{
      id: "#{subscription.id}:#{event_key}",
      event_key: event_key,
      subscription_id: subscription.id,
      subscription_name: subscription.name,
      chain_id: subscription.chain_id,
      address: raw_event |> fetch(:address) |> normalize_address(),
      topics: raw_topics,
      data: fetch(raw_event, :data, ""),
      block_number: block_number,
      transaction_hash: tx_hash,
      log_index: log_index,
      decoded: decode_event(subscription, raw_event),
      raw: raw_event,
      received_at: DateTime.utc_now()
    }
  end

  defp decode_event(%{decoder: decoder}, raw_event) when is_function(decoder, 1), do: decoder.(raw_event)

  defp decode_event(%{event_abi: abi}, raw_event) when is_list(abi) do
    case decode_with_abi_spec(abi, raw_event) do
      {:ok, decoded} -> decoded
      :error -> decode_event(%{}, raw_event)
    end
  end

  defp decode_event(%{event_abi: abi}, raw_event) when is_map(abi) do
    case decode_with_abi_spec([Map.put_new(abi, :type, "event")], raw_event) do
      {:ok, decoded} -> decoded
      :error -> decode_simple_abi_event(abi, raw_event)
    end
  end

  defp decode_event(_subscription, raw_event) do
    %{
      signature_topic: raw_event |> fetch(:topics, []) |> List.wrap() |> List.first(),
      data: fetch(raw_event, :data, "")
    }
  end

  defp decode_with_abi_spec(abi_spec, raw_event) do
    topics = raw_event |> fetch(:topics, []) |> List.wrap() |> Enum.take(4)
    [topic0, topic1, topic2, topic3] = pad_topics(topics)

    with {:ok, signature_topic} <- hex_to_binary(topic0),
         {:ok, data} <- hex_to_binary(fetch(raw_event, :data, "0x")) do
      selectors =
        abi_spec
        |> stringify_keys()
        |> ABI.parse_specification(include_events?: true)
        |> Enum.filter(&(&1.type == :event))

      case ABI.Event.find_and_decode(
             selectors,
             signature_topic,
             hex_topic_or_nil(topic1),
             hex_topic_or_nil(topic2),
             hex_topic_or_nil(topic3),
             data
           ) do
        {%ABI.FunctionSelector{} = selector, values} ->
          {:ok, decoded_abi_event(selector, values, topic0)}

        _ ->
          :error
      end
    else
      _ -> :error
    end
  rescue
    _ -> :error
  end

  defp decoded_abi_event(selector, values, signature_topic) do
    decoded_values = Enum.map(values, &decoded_abi_value/1)

    %{
      event: selector.function,
      signature_topic: signature_topic,
      args: Map.new(decoded_values, &{&1.name, &1.value}),
      indexed: decoded_values |> Enum.filter(& &1.indexed) |> Map.new(&{&1.name, &1.value}),
      non_indexed: decoded_values |> Enum.reject(& &1.indexed) |> Map.new(&{&1.name, &1.value}),
      values: decoded_values
    }
  end

  defp decoded_abi_value({name, type, indexed, value}) do
    %{
      name: name,
      type: type,
      indexed: indexed,
      value: normalize_decoded_value(type, value)
    }
  end

  defp normalize_decoded_value(_type, {:dynamic, value}) do
    %{indexed_dynamic_hash: binary_to_hex(value)}
  end

  defp normalize_decoded_value("address", value) when is_binary(value), do: binary_to_hex(value)
  defp normalize_decoded_value("bytes" <> _rest, value) when is_binary(value), do: binary_to_hex(value)
  defp normalize_decoded_value("string", value) when is_binary(value), do: value

  defp normalize_decoded_value(type, values) when is_list(values) do
    Enum.map(values, &normalize_decoded_value(type, &1))
  end

  defp normalize_decoded_value(type, value) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> Enum.map(&normalize_decoded_value(type, &1))
  end

  defp normalize_decoded_value(_type, value), do: value

  defp decode_simple_abi_event(abi, raw_event) do
    topics = List.wrap(fetch(raw_event, :topics, []))
    inputs = List.wrap(fetch(abi, :inputs, []))
    indexed_inputs = Enum.filter(inputs, &truthy?(fetch(&1, :indexed, false)))

    %{
      event: fetch(abi, :name, "UnknownEvent"),
      signature_topic: List.first(topics),
      indexed: decode_indexed_topics(indexed_inputs, Enum.drop(topics, 1)),
      non_indexed_data: fetch(raw_event, :data, "")
    }
  end

  defp decode_indexed_topics(inputs, topics) do
    inputs
    |> Enum.zip(topics)
    |> Map.new(fn {input, topic} -> {fetch(input, :name, "arg"), topic} end)
  end

  defp pad_topics(topics), do: Enum.take(topics ++ [nil, nil, nil, nil], 4)

  defp hex_topic_or_nil(nil), do: nil

  defp hex_topic_or_nil(topic) do
    case hex_to_binary(topic) do
      {:ok, binary} -> binary
      :error -> nil
    end
  end

  defp hex_to_binary(nil), do: {:ok, <<>>}
  defp hex_to_binary(""), do: {:ok, <<>>}

  defp hex_to_binary(value) do
    hex =
      value
      |> to_string()
      |> String.trim()
      |> strip_hex_prefix()

    hex = if rem(String.length(hex), 2) == 1, do: "0" <> hex, else: hex

    case Base.decode16(hex, case: :mixed) do
      {:ok, binary} -> {:ok, binary}
      :error -> :error
    end
  end

  defp strip_hex_prefix("0x" <> hex), do: hex
  defp strip_hex_prefix("0X" <> hex), do: hex
  defp strip_hex_prefix(hex), do: hex

  defp binary_to_hex(value) when is_binary(value), do: "0x" <> Base.encode16(value, case: :lower)

  defp stringify_keys(value) when is_list(value), do: Enum.map(value, &stringify_keys/1)

  defp stringify_keys(value) when is_map(value) do
    Map.new(value, fn {key, nested_value} -> {to_string(key), stringify_keys(nested_value)} end)
  end

  defp stringify_keys(value), do: value

  defp store_event(state, subscription, event) do
    subscription =
      subscription
      |> Map.put(:cursor_block, max(subscription.cursor_block, event.block_number))
      |> Map.put(:updated_at, DateTime.utc_now())

    %{
      state
      | subscriptions: Map.put(state.subscriptions, subscription.id, subscription),
        events: Map.put(state.events, event.id, event),
        event_order: state.event_order ++ [event.id]
    }
  end

  defp maybe_deliver_webhook(%{webhook_url: url}, event, opts) when is_binary(url) and url != "" do
    if Keyword.get(opts, :notify, true) do
      req_options =
        Application.get_env(:lux, :event_monitor_req_options, [])
        |> Keyword.merge(Keyword.get(opts, :req_options, []))

      payload = %{
        subscription_id: event.subscription_id,
        event_id: event.id,
        event: event
      }

      case Req.post(url, Keyword.merge([json: payload], req_options)) do
        {:ok, %{status: status}} when status in 200..299 -> {:ok, status}
        {:ok, %{status: status, body: body}} -> {:error, %{status: status, body: body}}
        {:error, error} -> {:error, inspect(error)}
      end
    else
      :skipped
    end
  end

  defp maybe_deliver_webhook(_subscription, _event, _opts), do: :skipped

  defp fetch_logs(subscription, opts) do
    params = log_params(subscription, opts)
    logs = fetch(opts, :logs)
    log_fetcher = fetch(opts, :log_fetcher)

    cond do
      is_list(logs) ->
        {:ok, logs, params}

      is_function(log_fetcher, 1) ->
        fetch_logs_with_fetcher(log_fetcher, params)

      true ->
        fetch_logs_with_etherscan(params, opts)
    end
  end

  defp fetch_logs_with_fetcher(log_fetcher, params) do
    case log_fetcher.(params) do
      {:ok, logs} -> {:ok, logs, params}
      logs when is_list(logs) -> {:ok, logs, params}
      {:error, reason} -> {:error, reason}
      other -> {:error, {:invalid_log_fetcher_response, other}}
    end
  end

  defp fetch_logs_with_etherscan(params, opts) do
    case GetLogs.focus(params, fetch(opts, :req_options, [])) do
      {:ok, %{result: logs}} -> {:ok, logs, params}
      {:ok, logs} when is_list(logs) -> {:ok, logs, params}
      {:error, reason} -> {:error, reason}
    end
  end

  defp log_params(subscription, opts) do
    from_block = opts |> fetch(:from_block, subscription.start_block) |> parse_int()
    to_block = opts |> fetch(:to_block, from_block) |> parse_int()

    %{
      chainid: subscription.chain_id,
      fromBlock: from_block,
      toBlock: to_block,
      page: opts |> fetch(:page, 1) |> parse_int(),
      offset: opts |> fetch(:offset, 1000) |> parse_int()
    }
    |> maybe_put(:address, subscription.address)
    |> put_topic_params(subscription.topics)
  end

  defp poll_opts(subscription, opts) do
    to_block = fetch(opts, :to_block)

    if blank?(to_block) do
      {:error, :to_block_required}
    else
      from_block = subscription.cursor_block + 1
      {:ok, opts |> Keyword.put(:from_block, from_block) |> Keyword.put(:to_block, parse_int(to_block))}
    end
  end

  defp fetch_next_to_block(subscription, opts) do
    opts |> fetch(:to_block, subscription.cursor_block + 1) |> parse_int()
  end

  defp replay_from_state(state, opts) do
    limit = opts |> fetch(:limit, 100) |> parse_int()
    subscription_id = fetch(opts, :subscription_id)
    from_block = fetch(opts, :from_block)
    to_block = fetch(opts, :to_block)

    state.event_order
    |> Enum.map(&state.events[&1])
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(fn event ->
      (blank?(subscription_id) or event.subscription_id == subscription_id) and
        (blank?(from_block) or event.block_number >= parse_int(from_block)) and
        (blank?(to_block) or event.block_number <= parse_int(to_block))
    end)
    |> Enum.take(limit)
  end

  defp dashboard_from_state(state) do
    subscriptions = Map.values(state.subscriptions)
    events = Enum.map(state.event_order, &state.events[&1]) |> Enum.reject(&is_nil/1)

    %{
      subscriptions: length(subscriptions),
      active_subscriptions: Enum.count(subscriptions, &(&1.status == :active)),
      stored_events: length(events),
      chains: Enum.frequencies_by(subscriptions, & &1.chain_id),
      cursors: Enum.map(subscriptions, &Map.take(&1, [:id, :name, :chain_id, :address, :cursor_block])),
      pollers: Map.keys(state.pollers),
      recent_events: events |> Enum.reverse() |> Enum.take(@default_recent_limit)
    }
  end

  defp fetch_subscription(state, subscription_id) do
    case Map.fetch(state.subscriptions, subscription_id) do
      {:ok, subscription} -> {:ok, subscription}
      :error -> {:error, :subscription_not_found}
    end
  end

  defp topics_from(attrs) do
    explicit_topics = fetch(attrs, :topics)

    topics =
      cond do
        is_list(explicit_topics) -> explicit_topics
        is_map(explicit_topics) -> Enum.map(@topic_indexes, &fetch(explicit_topics, :"topic#{&1}"))
        true -> Enum.map(@topic_indexes, &fetch(attrs, :"topic#{&1}"))
      end

    topics
    |> Enum.map(&normalize_topic/1)
    |> trim_trailing_blanks()
  end

  defp put_topic_params(params, topics) do
    topics
    |> Enum.with_index()
    |> Enum.reduce(params, fn {topic, index}, acc ->
      maybe_put(acc, :"topic#{index}", topic)
    end)
  end

  defp trim_trailing_blanks(topics) do
    topics
    |> Enum.reverse()
    |> Enum.drop_while(&blank?/1)
    |> Enum.reverse()
  end

  defp validate_address(nil), do: :ok

  defp validate_address(address) do
    if Regex.match?(~r/^0x[a-f0-9]{40}$/, address) do
      :ok
    else
      {:error, {:invalid_address, address}}
    end
  end

  defp normalize_address(nil), do: nil
  defp normalize_address(""), do: nil
  defp normalize_address(address) when is_binary(address), do: String.downcase(address)
  defp normalize_address(address), do: address |> to_string() |> normalize_address()

  defp normalize_topic(nil), do: nil
  defp normalize_topic(""), do: nil
  defp normalize_topic(topic) when is_binary(topic), do: String.downcase(topic)
  defp normalize_topic(topic), do: to_string(topic)

  defp block_number_from(raw_event) do
    fetch(raw_event, :block_number, fetch(raw_event, :blockNumber, 0))
  end

  defp parse_int(value) when is_integer(value), do: value

  defp parse_int(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.trim_leading("0x")
    |> parse_numeric_string(value)
  end

  defp parse_int(nil), do: 0
  defp parse_int(value), do: value |> to_string() |> parse_int()

  defp parse_numeric_string("", _original), do: 0

  defp parse_numeric_string(value, original) do
    base = if String.starts_with?(String.downcase(original), "0x"), do: 16, else: 10

    case Integer.parse(value, base) do
      {integer, _rest} -> integer
      :error -> 0
    end
  end

  defp maybe_put(map, _key, value) when value in [nil, ""], do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp fetch(map, key, default \\ nil)

  defp fetch(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end

  defp fetch(keyword, key, default) when is_list(keyword), do: Keyword.get(keyword, key, default)
  defp fetch(_value, _key, default), do: default

  defp blank?(value), do: value in [nil, ""]

  defp truthy?(value), do: value in [true, "true", "1", 1]

  defp atomize_known_state(snapshot) do
    %{
      subscriptions: fetch(snapshot, :subscriptions, %{}),
      events: fetch(snapshot, :events, %{}),
      event_order: fetch(snapshot, :event_order, []),
      pollers: fetch(snapshot, :pollers, %{})
    }
  end
end
