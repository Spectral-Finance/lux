defmodule Lux.Integrations.Web3.Events.EventMonitor do
  @moduledoc """
  GenServer for real-time monitoring of smart contract events.

  Polls for new events based on active subscriptions and dispatches
  them to subscribers via callbacks or webhook notifications.
  """

  use GenServer

  defstruct [:rpc_url, :chain, :poll_interval_ms, :last_block, :subscriptions, :event_store, :plug]

  alias Lux.Integrations.Web3.Events.EventDecoder

  # Client API

  def start_link(opts) do
    name = opts[:name]
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def add_watch(pid, params) do
    GenServer.call(pid, {:add_watch, params})
  end

  def remove_watch(pid, watch_id) do
    GenServer.call(pid, {:remove_watch, watch_id})
  end

  def get_events(pid, opts \\ []) do
    GenServer.call(pid, {:get_events, opts})
  end

  def status(pid) do
    GenServer.call(pid, :status)
  end

  # Server

  @impl true
  def init(opts) do
    state = %__MODULE__{
      rpc_url: opts[:rpc_url],
      chain: opts[:chain] || :ethereum,
      poll_interval_ms: opts[:poll_interval_ms] || 15_000,
      last_block: opts[:from_block],
      subscriptions: %{},
      event_store: [],
      plug: opts[:plug]
    }

    if opts[:auto_start] != false do
      send(self(), :poll)
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:add_watch, params}, _from, state) do
    id = System.unique_integer([:positive])
    watch = %{
      id: id,
      address: params[:address],
      topics: params[:topics],
      handler: params[:handler]
    }

    subs = Map.put(state.subscriptions, id, watch)
    {:reply, {:ok, id}, %{state | subscriptions: subs}}
  end

  @impl true
  def handle_call({:remove_watch, watch_id}, _from, state) do
    case Map.get(state.subscriptions, watch_id) do
      nil -> {:reply, {:error, :not_found}, state}
      _watch ->
        subs = Map.delete(state.subscriptions, watch_id)
        {:reply, :ok, %{state | subscriptions: subs}}
    end
  end

  @impl true
  def handle_call({:get_events, opts}, _from, state) do
    events = filter_events(state.event_store, opts)
    {:reply, {:ok, events}, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, %{
      chain: state.chain,
      last_block: state.last_block,
      watches: map_size(state.subscriptions),
      events_stored: length(state.event_store)
    }, state}
  end

  @impl true
  def handle_info(:poll, state) do
    state = poll_events(state)
    Process.send_after(self(), :poll, state.poll_interval_ms)
    {:noreply, state}
  end

  defp poll_events(%{subscriptions: subs} = state) when map_size(subs) == 0, do: state

  defp poll_events(state) do
    opts = [rpc_url: state.rpc_url] ++ if(state.plug, do: [plug: state.plug], else: [])

    # Get current block
    current_block = case rpc_call("eth_blockNumber", [], opts) do
      {:ok, hex} -> parse_hex(hex)
      _ -> state.last_block
    end

    from_block = (state.last_block || current_block) + 1

    if from_block > current_block do
      state
    else
      # Fetch logs for each subscription
      new_events = state.subscriptions
        |> Map.values()
        |> Enum.flat_map(fn watch ->
          filter = %{
            "fromBlock" => "0x#{Integer.to_string(from_block, 16)}",
            "toBlock" => "0x#{Integer.to_string(current_block, 16)}"
          }

          filter = if watch.address, do: Map.put(filter, "address", watch.address), else: filter
          filter = if watch.topics, do: Map.put(filter, "topics", watch.topics), else: filter

          case rpc_call("eth_getLogs", [filter], opts) do
            {:ok, logs} when is_list(logs) ->
              Enum.map(logs, fn log ->
                decoded = EventDecoder.decode(log)
                Map.put(decoded, :watch_id, watch.id)
              end)
            _ -> []
          end
        end)

      # Notify handlers
      Enum.each(new_events, fn event ->
        watch = Map.get(state.subscriptions, event.watch_id)
        if watch && watch.handler, do: watch.handler.(event)
      end)

      %{state |
        last_block: current_block,
        event_store: state.event_store ++ new_events
      }
    end
  end

  defp filter_events(events, opts) do
    events
    |> maybe_filter(:type, opts[:type])
    |> maybe_filter(:address, opts[:address])
    |> Enum.take(opts[:limit] || 100)
  end

  defp maybe_filter(events, _key, nil), do: events
  defp maybe_filter(events, key, value) do
    Enum.filter(events, &(Map.get(&1, key) == value))
  end

  defp rpc_call(method, params, opts) do
    body = %{jsonrpc: "2.0", id: 1, method: method, params: params}
    req_opts = [url: opts[:rpc_url], method: :post, json: body, retry: false]
    req_opts = if opts[:plug], do: Keyword.put(req_opts, :plug, opts[:plug]), else: req_opts

    case Req.request(req_opts) do
      {:ok, %{status: 200, body: %{"result" => result}}} -> {:ok, result}
      {:ok, %{body: body}} -> {:error, body}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_hex("0x" <> hex), do: String.to_integer(hex, 16)
  defp parse_hex(_), do: 0
end
