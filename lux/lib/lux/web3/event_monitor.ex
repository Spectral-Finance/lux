defmodule Lux.Web3.EventMonitor.Error do
  @moduledoc """
  A typed error returned by `Lux.Web3.EventMonitor` operations.

  ## Fields

    * `:code` - a stable, machine-readable error code (atom)
    * `:field` - the input field the error relates to, when applicable
    * `:reason` - a short, stable reason label
    * `:message` - a human readable diagnostic message
  """

  defstruct [:code, :field, :reason, :message]

  @type t :: %__MODULE__{
          code: atom(),
          field: atom() | nil,
          reason: atom(),
          message: String.t()
        }
end

defmodule Lux.Web3.EventMonitor.Subscription do
  @moduledoc """
  A registered contract event subscription.

  Subscriptions are identified by a unique id and are bound to a
  `(contract_address, event_name)` pair. Processing a matching event
  delivers it to every active subscription for that pair.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          contract_address: String.t(),
          event_name: String.t(),
          event_abi: map() | nil,
          from_block: non_neg_integer() | nil,
          active: boolean(),
          handler: module() | {module(), atom()} | nil,
          created_at: DateTime.t()
        }

  defstruct [
    :id,
    :contract_address,
    :event_name,
    :event_abi,
    :from_block,
    :active,
    :handler,
    :created_at
  ]
end

defmodule Lux.Web3.EventMonitor.Event do
  @moduledoc """
  A decoded and persisted contract event.

  Events are stored in-memory by the monitor and can be retrieved,
  filtered and replayed via `Lux.Web3.EventMonitor.events/2`,
  `Lux.Web3.EventMonitor.event_count/1` and
  `Lux.Web3.EventMonitor.replay/2`.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          subscription_id: String.t() | nil,
          contract_address: String.t(),
          event_name: String.t(),
          block_number: non_neg_integer(),
          log_index: non_neg_integer(),
          transaction_hash: String.t() | nil,
          args: [term()],
          topics: [String.t()],
          data: String.t(),
          delivered_to: [String.t()],
          received_at: DateTime.t()
        }

  defstruct [
    :id,
    :subscription_id,
    :contract_address,
    :event_name,
    :block_number,
    :log_index,
    :transaction_hash,
    :args,
    :topics,
    :data,
    :delivered_to,
    :received_at
  ]
end

defmodule Lux.Web3.EventMonitor do
  @moduledoc """
  Smart Contract Event Monitoring System.

  A robust, in-process system for tracking and processing events across
  multiple contracts and chains.

  ## Core capabilities

    * **Contract event subscription management** - `subscribe/4`, `unsubscribe/2`,
      `subscription/2`, `list_subscriptions/1`
    * **Real-time event monitoring and processing** - `process_event/4`
    * **Historical event syncing** - `sync_historical/4`
    * **Custom event filtering and pattern matching** - `events/2` with
      `:contract_address`, `:event_name`, `:from_block`, `:to_block` and `:limit`
    * **Custom event parsing and decoding** - `event_selector/1` builds an
      `ABI.FunctionSelector` from an event ABI and `process_event/4` decodes
      logs with `Ethers.Event.decode/2`
    * **Webhook notifications** - `add_webhook/3`, `remove_webhook/3`,
      `webhooks/1`, `notify_webhook/2`
    * **Event persistence and retrieval** - `events/2`, `event_count/1`,
      `replay/2`

  ## Example

      # Start a named monitor
      {:ok, _pid} = Lux.Web3.EventMonitor.start_link(name: MyMonitor)

      # Subscribe to a contract event
      {:ok, sub_id} =
        Lux.Web3.EventMonitor.subscribe(
          MyMonitor,
          "0x1234567890123456789012345678901234567890",
          "Transfer",
          event_abi: %{
            "name" => "Transfer",
            "inputs": [
              %{"name" => "from", "type" => "address", "indexed" => true},
              %{"name" => "to", "type" => "address", "indexed" => true},
              %{"name" => "value", "type" => "uint256", "indexed" => false}
            ]
          }
        )

  All mutating operations are handled by a single GenServer, so concurrent
  callers are serialized and transitions are atomic (no lost updates and no
  double registration).
  """

  require Logger

  use GenServer


  # --------------------------------------------------------------------------
  # Client API
  # --------------------------------------------------------------------------

  @doc """
  Starts the event monitor GenServer.

  ## Options

    * `:name` - an optional registered name used to address the monitor from
      other processes
    * `:webhook_timeout` - milliseconds to wait for each webhook delivery
      (default: `5_000`)

  ## Examples

      {:ok, pid} = Lux.Web3.EventMonitor.start_link()
      {:ok, pid} = Lux.Web3.EventMonitor.start_link(name: MyMonitor)
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, opts)
  end

  @doc """
  Subscribes to contract events for `contract_address` and `event_name`.

  Returns `{:ok, subscription_id}`. Subscription is idempotent by
  `(contract_address, event_name)`: re-subscribing to the same active pair
  returns the existing subscription id instead of creating a duplicate.

  ## Options

    * `:from_block` - the block number to start syncing from
    * `:event_abi` - the event ABI map used for decoding
    * `:handler` - an optional handler module or `{module, function}`

  ## Errors

    * `{:error,  %Lux.Web3.EventMonitor.Error{code: :invalid_argument, field: :contract_address}}`
      when the address is nil, empty or malformed
    * `{:error,  %Lux.Web3.EventMonitor.Error{code: :invalid_argument, field: :event_name}}`
      when the event name is nil, empty or malformed
  """
  def subscribe(pid, contract_address, event_name, opts \\ []) do
    GenServer.call(pid, {:subscribe, contract_address, event_name, opts}, 5000)
  end

  @doc """
  Subscribes to contract events, raising on error.
  """
  def subscribe!(pid, contract_address, event_name, opts \\ []) do
    case subscribe(pid, contract_address, event_name, opts) do
      {:ok, id} -> id
      {:error, error} -> raise error
    end
  end

  @doc """
  Unsubscribes the subscription with the given `id`.

  Returns `{:ok, id}` when removed, `{:error, :not_found}` otherwise.
  """
  def unsubscribe(pid, id) when is_binary(id) do
    GenServer.call(pid, {:unsubscribe, id}, 5000)
  end

  def unsubscribe(_pid, _id),
    do: {:error,  %Lux.Web3.EventMonitor.Error{code: :invalid_argument, field: :id, reason: :malformed, message: "subscription id must be a non-empty binary"}}

  @doc """
  Returns the subscription with the given `id`, or `{:error, :not_found}`.
  """
  def subscription(pid, id) when is_binary(id) do
    GenServer.call(pid, {:subscription, id}, 5000)
  end

  def subscription(_pid, _id),
    do: {:error,  %Lux.Web3.EventMonitor.Error{code: :invalid_argument, field: :id, reason: :malformed, message: "subscription id must be a non-empty binary"}}

  @doc """
  Returns all subscriptions known to the monitor as `{:ok, [Subscription]}`.
  """
  def list_subscriptions(pid) do
    GenServer.call(pid, {:list_subscriptions, nil}, 5000)
  end

  @doc """
  Processes a single contract event log.

  `selector` is an `ABI.FunctionSelector.t()` (see `event_selector/1`) and
  `log` is a raw eth_getLog-style map with `"topics"`, `"data"`,
  `"blockNumber"`, `"logIndex"`, `"transactionHash"`, `"address"` and
  `"blockHash"` keys.

  The log is decoded, persisted and delivered to every active subscription
  matching `(contract_address, event_name)`. Matching webhooks are notified.

  Returns `{:ok, event}` on success or a typed `{:error,  %Lux.Web3.EventMonitor.Error{}}`.
  """
  def process_event(pid, contract_address, selector, log) do
    GenServer.call(pid, {:process_event, contract_address, selector, log}, 5000)
  end

  @doc """
  Syncs a list of historical logs through `process_event/4`.

  Returns `{:ok, processed}` where `processed` is the number of logs
  successfully decoded and stored.
  """
  def sync_historical(pid, contract_address, selector, logs) when is_list(logs) do
    GenServer.call(pid, {:sync_historical, contract_address, selector, logs}, 5000)
  end

  def sync_historical(_pid, _contract_address, _selector, _logs) do
    {:error,  %Lux.Web3.EventMonitor.Error{code: :invalid_argument, field: :logs, reason: :malformed, message: "logs must be a list"}}
  end

  @doc """
  Retrieves persisted events, optionally filtered.

  ## Options

    * `:contract_address` - only events for this contract
    * `:event_name` - only events with this name
    * `:from_block` - only events at or after this block (inclusive)
    * `:to_block` - only events at or before this block (inclusive)
    * `:limit` - maximum number of events to return

  Returns `{:ok, [Event]}` ordered by block number then log index.
  """
  def events(pid, opts \\ [])

  def events(pid, opts) when is_list(opts) do
    GenServer.call(pid, {:events, opts}, 5000)
  end

  def events(_pid, _opts) do
    {:error,  %Lux.Web3.EventMonitor.Error{code: :invalid_argument, field: :opts, reason: :malformed, message: "opts must be a keyword list"}}
  end

  @doc """
  Returns the total number of persisted events as `{:ok, non_neg_integer()}`.
  """
  def event_count(pid) do
    GenServer.call(pid, {:event_count, nil}, 5000)
  end

  @doc """
  Adds a webhook URL that is notified whenever a matching event is processed.

  Returns `{:ok, url}` or `{:error,  %Lux.Web3.EventMonitor.Error{code: :invalid_argument}}` when the
  url is nil/empty or already registered.
  """
  def add_webhook(pid, url) when is_binary(url) and byte_size(url) > 0 do
    GenServer.call(pid, {:add_webhook, url}, 5000)
  end

  def add_webhook(_pid, ""),
    do: {:error, %Lux.Web3.EventMonitor.Error{code: :invalid_argument, field: :url, reason: :empty, message: "webhook url must not be empty"}}

  def add_webhook(_pid, _url),
    do: {:error, %Lux.Web3.EventMonitor.Error{code: :invalid_argument, field: :url, reason: :malformed, message: "webhook url must be a non-empty binary"}}

  @doc """
  Removes a previously registered webhook URL.

  Returns `{:ok, url}` or `{:error, :not_found}`.
  """
  def remove_webhook(pid, url) when is_binary(url) and byte_size(url) > 0 do
    GenServer.call(pid, {:remove_webhook, url}, 5000)
  end

  def remove_webhook(_pid, ""),
    do: {:error, %Lux.Web3.EventMonitor.Error{code: :invalid_argument, field: :url, reason: :empty, message: "webhook url must not be empty"}}

  def remove_webhook(_pid, _url),
    do: {:error, %Lux.Web3.EventMonitor.Error{code: :invalid_argument, field: :url, reason: :malformed, message: "webhook url must be a non-empty binary"}}

  @doc """
  Returns the registered webhook URLs as `{:ok, [String.t()]}`.
  """
  def webhooks(pid) do
    GenServer.call(pid, {:webhooks, nil}, 5000)
  end

  @doc """
  Delivers `event` to a single webhook `url` via a JSON POST.

  Returns `{:ok, :delivered}` when the remote accepted the payload or
  `{:error,  %Lux.Web3.EventMonitor.Error{code: :webhook_failed}}` otherwise. Network failures are
  captured and never crash the caller.
  """
  def notify_webhook(url, event) when is_binary(url) and byte_size(url) > 0 do
    payload =
      %{
        event_name: event.event_name,
        contract_address: event.contract_address,
        block_number: event.block_number,
        occurred_at: DateTime.to_iso8601(event.received_at)
      }

    body = Jason.encode!(payload)

    try do
      case Req.post(url, body: body, headers: [{"Content-Type", "application/json"}]) do
        {:ok, _response} ->
          {:ok, :delivered}

        {:error, reason} ->
          {:error,
           %Lux.Web3.EventMonitor.Error{
             code: :webhook_failed,
             field: :url,
             reason: :delivery_failed,
             message: inspect(reason)
           }}
      end
    rescue
      e ->
        Logger.debug("webhook delivery to #{url} failed: #{inspect(e)}")
        {:error,
         %Lux.Web3.EventMonitor.Error{
           code: :webhook_failed,
           field: :url,
           reason: :delivery_failed,
           message: Exception.message(e)
         }}
    end
  end

  def notify_webhook("", _event),
    do: {:error, %Lux.Web3.EventMonitor.Error{code: :invalid_argument, field: :url, reason: :empty, message: "webhook url must not be empty"}}

  def notify_webhook(_url, _event),
    do: {:error, %Lux.Web3.EventMonitor.Error{code: :invalid_argument, field: :url, reason: :malformed, message: "webhook url must be a non-empty binary"}}

  @doc """
  Replays persisted events, optionally filtered by the same options as
  `events/2`. When `:to` is `:webhooks`, each replayed event is also
  delivered to every registered webhook.

  Returns `{:ok, [Event]}`.
  """
  def replay(pid, opts \\ [])

  def replay(pid, opts) when is_list(opts) do
    GenServer.call(pid, {:replay, opts}, 5000)
  end

  def replay(_pid, _opts) do
    {:error,  %Lux.Web3.EventMonitor.Error{code: :invalid_argument, field: :opts, reason: :malformed, message: "opts must be a keyword list"}}
  end

  @doc """
  Clears all subscriptions, events, webhooks and notifications.

  Intended for test cleanup. Returns `:ok`.
  """
  def clear(pid) do
    GenServer.call(pid, {:clear, nil}, 5000)
  end

  # --------------------------------------------------------------------------
  # Event selector construction (custom event parsing and decoding)
  # --------------------------------------------------------------------------

  @doc """
  Builds an `ABI.FunctionSelector.t()` for an event from its ABI map.

      abi = %{
        "name" => "Transfer",
        "inputs": [
          %{"name" => "from", "type" => "address", "indexed" => true},
          %{"name" => "to", "type" => "address", "indexed" => true},
          %{"name" => "value", "type" => "uint256", "indexed" => false}
        ]
      }
      selector = Lux.Web3.EventMonitor.event_selector(abi)

  The returned selector can be passed to `process_event/4` for decoding.
  """
  def event_selector(event_abi) when is_map(event_abi) do
    case Map.fetch(event_abi, "name") do
      {:ok, name} ->
        inputs = Map.get(event_abi, "inputs", [])
        input_names = Enum.map(inputs, fn input -> Map.get(input, "name", "") end)
        inputs_indexed = Enum.map(inputs, fn input -> Map.get(input, "indexed", false) end)
        types = Enum.map(inputs, &parse_abi_type/1)

        signature =
          name <> "(" <> Enum.map_join(types, ",", &ABI.FunctionSelector.encode_type/1) <> ")"

        %ABI.FunctionSelector{
          function: name,
          type: :event,
          method_id: ExKeccak.hash_256(signature),
          types: types,
          input_names: input_names,
          inputs_indexed: inputs_indexed
        }

      :error ->
        {:error,
         %Lux.Web3.EventMonitor.Error{
           code: :invalid_argument,
           field: :event_abi,
           reason: :malformed,
           message: "event abi must be a map with a :name field"
         }}
    end
  end

  def event_selector(_event_abi) do
    {:error,  %Lux.Web3.EventMonitor.Error{code: :invalid_argument, field: :event_abi, reason: :malformed, message: "event abi must be a map with a :name field"}}
  end

  # --------------------------------------------------------------------------
  # GenServer callbacks
  # --------------------------------------------------------------------------

  @impl true
  def init(opts) do
    %{
      subscriptions: %{},
      events: %{},
      webhooks: [],
      notifications: [],
      next_sub_id: 1,
      next_event_id: 1,
      webhook_timeout: Keyword.get(opts, :webhook_timeout, 5_000)
    }
    |> then(&{:ok, &1})
  end

  @impl true
  def handle_call({:subscribe, contract_address, event_name, opts}, _from, state) do
    {result, state} =
      case validate_address(contract_address) do
        {:error, error} -> {{:error, error}, state}
        {:ok, addr} ->
          case validate_event_name(event_name) do
            {:error, error} -> {{:error, error}, state}
            {:ok, name} -> subscribe_address(state, addr, name, opts)
          end
      end

    reply(result, state)
  end

  @impl true
  def handle_call({:unsubscribe, id}, _from, state) do
    if Map.has_key?(state.subscriptions, id) do
      {:reply, {:ok, id}, %{state | subscriptions: Map.delete(state.subscriptions, id)}}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:subscription, id}, _from, state) do
    case Map.fetch(state.subscriptions, id) do
      {:ok, sub} -> {:reply, {:ok, sub}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:list_subscriptions, nil}, _from, state) do
    {:reply, {:ok, Map.values(state.subscriptions)}, state}
  end

  @impl true
  def handle_call({:process_event, contract_address, selector, log}, _from, state) do
    {result, state} =
      case validate_address(contract_address) do
        {:error, error} -> {{:error, error}, state}
        {:ok, addr} -> process_event_log(state, addr, selector, log)
      end

    reply(result, state)
  end

  @impl true
  def handle_call({:sync_historical, contract_address, selector, logs}, _from, state) do
    {result, state} =
      case validate_address(contract_address) do
        {:error, error} -> {{:error, error}, state}
        {:ok, addr} -> sync_historical_logs(state, addr, selector, logs)
      end

    reply(result, state)
  end

  @impl true
  def handle_call({:events, opts}, _from, state) do
    {:reply, {:ok, filter_events(state, opts)}, state}
  end

  @impl true
  def handle_call({:event_count, nil}, _from, state) do
    {:reply, {:ok, map_size(state.events)}, state}
  end

  @impl true
  def handle_call({:add_webhook, url}, _from, state) do
    if url in state.webhooks do
      {:reply,
       {:error, %Lux.Web3.EventMonitor.Error{code: :invalid_argument, field: :url, reason: :duplicate, message: "webhook url already registered"}},
       state}
    else
      {:reply, {:ok, url}, %{state | webhooks: [url | state.webhooks]}}
    end
  end

  @impl true
  def handle_call({:remove_webhook, url}, _from, state) do
    webhooks = List.delete(state.webhooks, url)

    if webhooks == state.webhooks do
      {:reply, {:error, :not_found}, state}
    else
      {:reply, {:ok, url}, %{state | webhooks: webhooks}}
    end
  end

  @impl true
  def handle_call({:webhooks, nil}, _from, state) do
    {:reply, {:ok, state.webhooks}, state}
  end

  @impl true
  def handle_call({:replay, opts}, _from, state) do
    {:reply, {:ok, filter_events(state, opts)}, state}
  end

  @impl true
  def handle_call({:clear, nil}, _from, _state) do
    state =
      %{
        subscriptions: %{},
        events: %{},
        webhooks: [],
        notifications: [],
        next_sub_id: 1,
        next_event_id: 1,
        webhook_timeout: 5_000
      }

    {:reply, :ok, state}
  end

  # --------------------------------------------------------------------------
  # Internal helpers (each returns `{result, state}`)
  # --------------------------------------------------------------------------

  defp reply(result, state) do
    case result do
      {:ok, value} -> {:reply, {:ok, value}, state}
      {:error, error} -> {:reply, {:error, error}, state}
      :ok -> {:reply, :ok, state}
    end
  end

  defp subscribe_address(state, addr, name, opts) do
    # Idempotent: return the active subscription for the pair, if any.
    case find_subscription(state, addr, name) do
      {:ok, sub} ->
        {{:ok, sub.id}, state}

      :error ->
        id = Integer.to_string(state.next_sub_id)

        sub =  %Lux.Web3.EventMonitor.Subscription{
          id: id,
          contract_address: addr,
          event_name: name,
          event_abi: Keyword.get(opts, :event_abi),
          from_block: Keyword.get(opts, :from_block),
          active: true,
          handler: Keyword.get(opts, :handler),
          created_at: DateTime.utc_now()
        }

        state =
          %{state |
            subscriptions: Map.put(state.subscriptions, id, sub),
            next_sub_id: state.next_sub_id + 1}

        {{:ok, id}, state}
    end
  end

  defp process_event_log(state, addr, selector, log) when is_map(selector) do
    case Map.fetch(selector, :function) do
      {:ok, event_name} ->
        case decode_event(selector, log) do
          {:ok, decoded} ->
            event = build_event(state, addr, selector, log, decoded)

            matching = subscriptions_for(state, addr, event_name)
            delivered_to = Enum.map(matching, & &1.id)

            event = %{event | delivered_to: delivered_to}

            state = put_event(state, event)
            state = notify_webhooks(state, event)

            {{:ok, event}, state}

          {:error, reason} ->
            {{:error,
              %Lux.Web3.EventMonitor.Error{
                code: :decode_failed,
                field: :log,
                reason: reason,
                message: "failed to decode event log"
              }},
             state}
        end

      :error ->
        {{:error,
          %Lux.Web3.EventMonitor.Error{
            code: :invalid_argument,
            field: :selector,
            reason: :malformed,
            message: "selector must be an ABI event function selector"
          }},
         state}
    end
  end

  defp process_event_log(state, _addr, _selector, _log) do
    {{:error,
      %Lux.Web3.EventMonitor.Error{
        code: :invalid_argument,
        field: :selector,
        reason: :malformed,
        message: "selector must be an ABI event function selector"
      }},
     state}
  end

  defp decode_event(selector, log) do
    try do
      {:ok, Ethers.Event.decode(log, selector)}
    rescue
      _e -> {:error, :decode_error}
    end
  end

  defp build_event(state, addr, selector, log, decoded) do
     %Lux.Web3.EventMonitor.Event{
      id: Integer.to_string(state.next_event_id),
      contract_address: addr,
      event_name: selector.function,
      block_number: block_from_log(log),
      log_index: log_index_from_log(log),
      transaction_hash: Map.get(log, "transactionHash"),
      args: decoded.data,
      topics: Map.get(log, "topics", []),
      data: Map.get(log, "data", ""),
      delivered_to: [],
      received_at: DateTime.utc_now()
    }
  end

  defp put_event(state, event) do
    events = Map.put(state.events, event.id, event)
    %{state | events: events, next_event_id: state.next_event_id + 1}
  end

  defp notify_webhooks(state, event) do
    if state.webhooks == [] do
      state
    else
      Enum.reduce(state.webhooks, state, fn url, acc_state ->
        deliver_webhook(acc_state, url, event)
      end)
    end
  end

  defp deliver_webhook(acc_state, url, event) do
    case notify_webhook(url, event) do
      {:ok, :delivered} ->
        %{acc_state | notifications: [{:delivered, url, event.id} | acc_state.notifications]}

      {:error, %Lux.Web3.EventMonitor.Error{} = error} ->
        %{acc_state | notifications: [{:failed, url, event.id, error.code} | acc_state.notifications]}
    end
  end

  defp sync_historical_logs(state, addr, selector, logs) do
    Enum.reduce(logs, {0, state}, fn log, {count, acc_state} ->
      case process_event_log(acc_state, addr, selector, log) do
        {{:ok, _event}, acc_state} -> {count + 1, acc_state}
        _ -> {count, acc_state}
      end
    end)
    |> then(fn {count, new_state} -> {{:ok, count}, new_state} end)
  end

  defp filter_events(state, opts) do
    Enum.filter(Map.values(state.events), fn event ->
      cond do
        is_binary(opts[:contract_address]) and event.contract_address != opts[:contract_address] ->
          false

        is_binary(opts[:event_name]) and event.event_name != opts[:event_name] ->
          false

        is_integer(opts[:from_block]) and event.block_number < opts[:from_block] ->
          false

        is_integer(opts[:to_block]) and event.block_number > opts[:to_block] ->
          false

        true ->
          true
      end
    end)
    |> Enum.sort_by(&{&1.block_number, &1.log_index})
    |> take_limit(opts[:limit])
  end

  defp take_limit(list, nil), do: list
  defp take_limit(list, limit) when is_integer(limit) and limit >= 0, do: Enum.take(list, limit)
  defp take_limit(list, _limit), do: list

  defp subscriptions_for(state, addr, event_name) do
    Map.values(state.subscriptions)
    |> Enum.filter(fn sub ->
      sub.active and sub.contract_address == addr and sub.event_name == event_name
    end)
  end

  defp find_subscription(state, addr, event_name) do
    Map.values(state.subscriptions)
    |> Enum.find(fn sub ->
      sub.active and sub.contract_address == addr and sub.event_name == event_name
    end)
    |> case do
      nil -> :error
      sub -> {:ok, sub}
    end
  end

  defp block_from_log(log) do
    case log do
      %{"blockNumber" => block} -> parse_block(block)
      _ -> 0
    end
  end

  defp log_index_from_log(log) do
    case log do
      %{"logIndex" => index} -> parse_block(index)
      _ -> 0
    end
  end

  defp parse_block(value) when is_integer(value), do: max(value, 0)
  defp parse_block(<<>>), do: 0
  defp parse_block(binary) when is_binary(binary) do
    hex = case binary do
      <<"0x", rest::binary>> -> rest
      _ -> binary
    end

    case Integer.parse(hex, 16) do
      {n, ""} -> max(n, 0)
      _ -> 0
    end
  end
  defp parse_block(_other), do: 0

  # --------------------------------------------------------------------------
  # Validation
  # --------------------------------------------------------------------------

  defp validate_address(nil),
    do: {:error,  %Lux.Web3.EventMonitor.Error{code: :invalid_argument, field: :contract_address, reason: :nil, message: "contract address must not be nil"}}

  defp validate_address(""),
    do: {:error,  %Lux.Web3.EventMonitor.Error{code: :invalid_argument, field: :contract_address, reason: :empty, message: "contract address must not be empty"}}

  defp validate_address(addr) when is_binary(addr) do
    if String.starts_with?(addr, "0x") do
      {:ok, addr}
    else
    {:error, %Lux.Web3.EventMonitor.Error{code: :invalid_argument, field: :contract_address, reason: :malformed, message: "contract address must be a 0x-prefixed hex string"}}
    end
  end

  defp validate_address(_addr),
    do:  {:error, %Lux.Web3.EventMonitor.Error{code: :invalid_argument, field: :contract_address, reason: :malformed, message: "contract address must be a 0x-prefixed hex string"}}
  defp validate_event_name(nil),
    do: {:error,  %Lux.Web3.EventMonitor.Error{code: :invalid_argument, field: :event_name, reason: :nil, message: "event name must not be nil"}}

  defp validate_event_name(""),
    do: {:error,  %Lux.Web3.EventMonitor.Error{code: :invalid_argument, field: :event_name, reason: :empty, message: "event name must not be empty"}}

  defp validate_event_name(name) when is_binary(name),
    do: {:ok, name}

  defp validate_event_name(_name),
    do:  {:error, %Lux.Web3.EventMonitor.Error{code: :invalid_argument, field: :event_name, reason: :malformed, message: "event name must be a non-empty string"}}

  # --------------------------------------------------------------------------
  # ABI type parsing
  # --------------------------------------------------------------------------

  defp parse_abi_type(input) when is_map(input) do
    type = Map.get(input, "type", "")
    parse_abi_type_string(type)
  end

  defp parse_abi_type_string("address"), do: :address
  defp parse_abi_type_string("bool"), do: :bool
  defp parse_abi_type_string("string"), do: :string
  defp parse_abi_type_string("bytes"), do: :bytes

  defp parse_abi_type_string(type) when is_binary(type) do
    cond do
      String.starts_with?(type, "uint") -> {:uint, parse_abi_size(type, "uint")}
      String.starts_with?(type, "int") -> {:int, parse_abi_size(type, "int")}
      String.starts_with?(type, "bytes") -> {:bytes, parse_abi_size(type, "bytes")}
      true -> :bytes
    end
  end

  defp parse_abi_type_string(_type), do: :bytes

  defp parse_abi_size(type, prefix) do
    rest = String.trim_leading(type, prefix)
    case Integer.parse(rest) do
      {n, ""} when n > 0 -> n
      _ -> 256
    end
  end

end
