defmodule Lux.EventMonitor.Store do
  @moduledoc """
  Persistent event storage using ETS for fast in-memory access.

  The Store provides event persistence and retrieval with support for:
  - Storing decoded event logs
  - Querying events by various criteria
  - Event replay capabilities
  - Automatic cleanup of old events

  ## Architecture

  Events are stored in ETS tables keyed by `{chain_id, transaction_hash, log_index}`
  for deduplication. Secondary indexes exist for efficient queries by address and
  block number.

  ## Usage

      {:ok, store} = Lux.EventMonitor.Store.start_link(name: :my_store)
      :ok = Lux.EventMonitor.Store.insert(store, event_log)
      {:ok, events} = Lux.EventMonitor.Store.query(store, %{address: "0x..."})
  """

  use GenServer

  alias Lux.EventMonitor.EventLog
  alias Lux.EventMonitor.Filter

  require Logger

  @type query_opts :: %{
          optional(:address) => String.t(),
          optional(:event_name) => String.t() | [String.t()],
          optional(:chain_id) => pos_integer(),
          optional(:from_block) => non_neg_integer(),
          optional(:to_block) => non_neg_integer(),
          optional(:limit) => pos_integer(),
          optional(:offset) => non_neg_integer(),
          optional(:order) => :asc | :desc
        }

  defstruct [:events_table, :index_table, :name, max_events: 100_000, ttl_seconds: 86_400]

  # Client API

  @doc """
  Starts the event store.

  ## Options

    * `:name` - Registered name for the GenServer (default: `__MODULE__`)
    * `:max_events` - Maximum number of events to store (default: 100,000)
    * `:ttl_seconds` - Time-to-live for events in seconds (default: 86,400 = 24 hours)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Inserts an event log into the store.

  Duplicate events (same chain_id, transaction_hash, and log_index) are silently
  ignored.
  """
  @spec insert(GenServer.server(), EventLog.t()) :: :ok
  def insert(store, %EventLog{} = event_log) do
    GenServer.call(store, {:insert, event_log})
  end

  @doc """
  Inserts a batch of event logs into the store.
  """
  @spec insert_batch(GenServer.server(), [EventLog.t()]) :: :ok
  def insert_batch(store, event_logs) when is_list(event_logs) do
    GenServer.call(store, {:insert_batch, event_logs})
  end

  @doc """
  Queries the store for events matching the given criteria.

  ## Query Options

    * `:address` - Filter by contract address
    * `:event_name` - Filter by event name
    * `:chain_id` - Filter by chain ID
    * `:from_block` - Minimum block number
    * `:to_block` - Maximum block number
    * `:limit` - Maximum number of results (default: 100)
    * `:offset` - Number of results to skip (default: 0)
    * `:order` - Sort order by block number (`:asc` or `:desc`, default: `:desc`)

  ## Returns

  `{:ok, events}` where events is a list of matching EventLog structs.
  """
  @spec query(GenServer.server(), query_opts()) :: {:ok, [EventLog.t()]}
  def query(store, opts \\ %{}) do
    GenServer.call(store, {:query, opts})
  end

  @doc """
  Returns the total count of events in the store.
  """
  @spec count(GenServer.server()) :: non_neg_integer()
  def count(store) do
    GenServer.call(store, :count)
  end

  @doc """
  Clears all events from the store.
  """
  @spec clear(GenServer.server()) :: :ok
  def clear(store) do
    GenServer.call(store, :clear)
  end

  @doc """
  Removes events older than the specified block number on the given chain.
  """
  @spec prune(GenServer.server(), pos_integer(), non_neg_integer()) :: non_neg_integer()
  def prune(store, chain_id, before_block) do
    GenServer.call(store, {:prune, chain_id, before_block})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    max_events = Keyword.get(opts, :max_events, 100_000)
    ttl_seconds = Keyword.get(opts, :ttl_seconds, 86_400)

    events_table = :ets.new(:"#{name}_events", [:set, :protected])
    index_table = :ets.new(:"#{name}_index", [:bag, :protected])

    state = %__MODULE__{
      events_table: events_table,
      index_table: index_table,
      name: name,
      max_events: max_events,
      ttl_seconds: ttl_seconds
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:insert, event_log}, _from, state) do
    do_insert(state, event_log)
    {:reply, :ok, state}
  end

  def handle_call({:insert_batch, event_logs}, _from, state) do
    Enum.each(event_logs, &do_insert(state, &1))
    {:reply, :ok, state}
  end

  def handle_call({:query, opts}, _from, state) do
    results = do_query(state, opts)
    {:reply, {:ok, results}, state}
  end

  def handle_call(:count, _from, state) do
    count = :ets.info(state.events_table, :size)
    {:reply, count, state}
  end

  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(state.events_table)
    :ets.delete_all_objects(state.index_table)
    {:reply, :ok, state}
  end

  def handle_call({:prune, chain_id, before_block}, _from, state) do
    pruned = do_prune(state, chain_id, before_block)
    {:reply, pruned, state}
  end

  @impl true
  def terminate(_reason, state) do
    :ets.delete(state.events_table)
    :ets.delete(state.index_table)
    :ok
  end

  # Internal implementation

  defp do_insert(state, %EventLog{} = event_log) do
    key = {event_log.chain_id, event_log.transaction_hash, event_log.log_index}
    now = System.system_time(:second)

    # Insert main record (no-op if already exists due to :set table)
    :ets.insert(state.events_table, {key, event_log, now})

    # Insert index entries for efficient querying
    addr = String.downcase(event_log.address || "")
    :ets.insert(state.index_table, {{:address, addr}, key})
    :ets.insert(state.index_table, {{:chain_block, event_log.chain_id, event_log.block_number}, key})

    if event_log.event_name do
      :ets.insert(state.index_table, {{:event_name, event_log.event_name}, key})
    end

    # Enforce max_events limit
    enforce_limit(state)
  end

  defp do_query(state, opts) do
    limit = Map.get(opts, :limit, 100)
    offset = Map.get(opts, :offset, 0)
    order = Map.get(opts, :order, :desc)

    # Get all events and apply filter
    all_events =
      :ets.tab2list(state.events_table)
      |> Enum.map(fn {_key, event_log, _ts} -> event_log end)

    # Build filter from query opts
    filter = Map.drop(opts, [:limit, :offset, :order])

    filtered =
      if map_size(filter) > 0 do
        Filter.filter_logs(all_events, filter)
      else
        all_events
      end

    # Sort and paginate
    sorted =
      case order do
        :asc -> Enum.sort_by(filtered, & &1.block_number, :asc)
        :desc -> Enum.sort_by(filtered, & &1.block_number, :desc)
      end

    sorted
    |> Enum.drop(offset)
    |> Enum.take(limit)
  end

  defp do_prune(state, chain_id, before_block) do
    # Find events to remove
    to_remove =
      :ets.tab2list(state.events_table)
      |> Enum.filter(fn {_key, event_log, _ts} ->
        event_log.chain_id == chain_id and event_log.block_number < before_block
      end)

    # Remove from events table and index
    Enum.each(to_remove, fn {key, event_log, _ts} ->
      :ets.delete(state.events_table, key)

      addr = String.downcase(event_log.address || "")
      :ets.match_delete(state.index_table, {{:address, addr}, key})
      :ets.match_delete(state.index_table, {{:chain_block, event_log.chain_id, event_log.block_number}, key})

      if event_log.event_name do
        :ets.match_delete(state.index_table, {{:event_name, event_log.event_name}, key})
      end
    end)

    length(to_remove)
  end

  defp enforce_limit(state) do
    current_size = :ets.info(state.events_table, :size)

    if current_size > state.max_events do
      # Remove oldest events (by insertion timestamp)
      to_remove = current_size - state.max_events

      :ets.tab2list(state.events_table)
      |> Enum.sort_by(fn {_key, _event, ts} -> ts end, :asc)
      |> Enum.take(to_remove)
      |> Enum.each(fn {key, event_log, _ts} ->
        :ets.delete(state.events_table, key)
        addr = String.downcase(event_log.address || "")
        :ets.match_delete(state.index_table, {{:address, addr}, key})
      end)
    end
  end
end
