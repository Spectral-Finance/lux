defmodule Lux.Web3.EventMonitor.EventStore do
  @moduledoc """
  Event storage, indexing, and replay engine for smart contract event monitoring (#75).

  Provides indexed querying, ring-buffer retention pruning, and historical event replay
  for backfilling, testing, or disaster recovery.
  """

  use GenServer
  alias Lux.Web3.EventMonitor.Schemas.MonitoredEvent

  @default_max_events 50_000

  @type state :: %{
          events: %{String.t() => MonitoredEvent.t()},
          event_ids: [String.t()],
          max_events: non_neg_integer()
        }

  # --- Client API ---

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Saves a monitored event into the store.
  """
  @spec store_event(GenServer.server(), MonitoredEvent.t()) :: {:ok, MonitoredEvent.t()}
  def store_event(server \\ __MODULE__, %MonitoredEvent{} = event) do
    GenServer.call(server, {:store_event, event})
  end

  @doc """
  Saves a batch of monitored events.
  """
  @spec store_batch(GenServer.server(), [MonitoredEvent.t()]) :: {:ok, non_neg_integer()}
  def store_batch(server \\ __MODULE__, events) when is_list(events) do
    GenServer.call(server, {:store_batch, events})
  end

  @doc """
  Retrieves an event by its unique ID.
  """
  @spec get_event(GenServer.server(), String.t()) :: {:ok, MonitoredEvent.t()} | {:error, :not_found}
  def get_event(server \\ __MODULE__, event_id) do
    GenServer.call(server, {:get_event, event_id})
  end

  @doc """
  Queries stored events with filtering, pagination, and ordering.
  """
  @spec query_events(GenServer.server(), map(), map()) :: {[MonitoredEvent.t()], non_neg_integer()}
  def query_events(server \\ __MODULE__, filters \\ %{}, pagination \\ %{}) do
    GenServer.call(server, {:query_events, filters, pagination})
  end

  @doc """
  Replays stored events for a given subscription or criteria.
  Calls `handler_fn.(event)` for each matching event.
  """
  @spec replay_events(GenServer.server(), map(), (MonitoredEvent.t() -> any())) ::
          {:ok, non_neg_integer()}
  def replay_events(server \\ __MODULE__, filters, handler_fn) when is_function(handler_fn, 1) do
    GenServer.call(server, {:replay_events, filters, handler_fn})
  end

  @doc """
  Returns count of stored events.
  """
  @spec count(GenServer.server()) :: non_neg_integer()
  def count(server \\ __MODULE__) do
    GenServer.call(server, :count)
  end

  @doc """
  Clears all stored events.
  """
  @spec clear(GenServer.server()) :: :ok
  def clear(server \\ __MODULE__) do
    GenServer.call(server, :clear)
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    max_events = Keyword.get(opts, :max_events, @default_max_events)
    {:ok, %{events: %{}, event_ids: [], max_events: max_events}}
  end

  @impl true
  def handle_call({:store_event, event}, _from, state) do
    {new_events, new_ids} = insert_event(state.events, state.event_ids, event, state.max_events)
    {:reply, {:ok, event}, %{state | events: new_events, event_ids: new_ids}}
  end

  @impl true
  def handle_call({:store_batch, events}, _from, state) do
    {new_events, new_ids} =
      Enum.reduce(events, {state.events, state.event_ids}, fn ev, {ev_map, id_list} ->
        insert_event(ev_map, id_list, ev, state.max_events)
      end)

    {:reply, {:ok, length(events)}, %{state | events: new_events, event_ids: new_ids}}
  end

  @impl true
  def handle_call({:get_event, id}, _from, state) do
    case Map.get(state.events, id) do
      nil -> {:reply, {:error, :not_found}, state}
      ev -> {:reply, {:ok, ev}, state}
    end
  end

  @impl true
  def handle_call({:query_events, filters, pagination}, _from, state) do
    filtered = filter_events(Map.values(state.events), filters)
    total_count = length(filtered)

    offset = pagination[:offset] || pagination["offset"] || 0
    limit = pagination[:limit] || pagination["limit"] || 50

    results =
      filtered
      |> Enum.sort_by(&{&1.block_number, &1.log_index}, :desc)
      |> Enum.drop(offset)
      |> Enum.take(limit)

    {:reply, {results, total_count}, state}
  end

  @impl true
  def handle_call({:replay_events, filters, handler_fn}, _from, state) do
    matched =
      state.events
      |> Map.values()
      |> filter_events(filters)
      |> Enum.sort_by(&{&1.block_number, &1.log_index}, :asc)

    Enum.each(matched, handler_fn)
    {:reply, {:ok, length(matched)}, state}
  end

  @impl true
  def handle_call(:count, _from, state) do
    {:reply, map_size(state.events), state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    {:reply, :ok, %{state | events: %{}, event_ids: []}}
  end

  # Helper to manage ring buffer cap
  defp insert_event(events_map, id_list, %MonitoredEvent{id: id} = event, max_events) do
    if Map.has_key?(events_map, id) do
      {Map.put(events_map, id, event), id_list}
    else
      new_map = Map.put(events_map, id, event)
      new_ids = [id | id_list]

      if length(new_ids) > max_events do
        {to_keep, to_drop} = Enum.split(new_ids, max_events)
        pruned_map = Enum.reduce(to_drop, new_map, &Map.delete(&2, &1))
        {pruned_map, to_keep}
      else
        {new_map, new_ids}
      end
    end
  end

  defp filter_events(events, filters) when is_map(filters) do
    Enum.filter(events, fn ev ->
      sub_match = is_nil(filters[:subscription_id]) or ev.subscription_id == filters[:subscription_id]
      chain_match = is_nil(filters[:chain]) or ev.chain == filters[:chain]
      chain_id_match = is_nil(filters[:chain_id]) or ev.chain_id == filters[:chain_id]
      contract_match =
        case filters[:contract_address] do
          nil -> true
          addr -> String.downcase(to_string(addr)) == ev.contract_address
        end
      event_match = is_nil(filters[:event_name]) or ev.event_name == filters[:event_name]
      block_min = is_nil(filters[:from_block]) or ev.block_number >= filters[:from_block]
      block_max = is_nil(filters[:to_block]) or ev.block_number <= filters[:to_block]

      sub_match and chain_match and chain_id_match and contract_match and event_match and block_min and block_max
    end)
  end
end
