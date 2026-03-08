defmodule Lux.Integrations.Web3.Events.EventStore do
  @moduledoc """
  Persistent event storage using ETS with optional disk persistence.

  Stores decoded events with indexing by contract address, event type,
  block number, and chain. Supports querying, pagination, and replay.
  """

  use GenServer

  defstruct [:table, :chain, :max_events, :persist_path]

  # Client API

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def store(pid \\ __MODULE__, event) do
    GenServer.call(pid, {:store, event})
  end

  def store_batch(pid \\ __MODULE__, events) do
    GenServer.call(pid, {:store_batch, events})
  end

  def query(pid \\ __MODULE__, filters \\ %{}) do
    GenServer.call(pid, {:query, filters})
  end

  def count(pid \\ __MODULE__) do
    GenServer.call(pid, :count)
  end

  def clear(pid \\ __MODULE__) do
    GenServer.call(pid, :clear)
  end

  def export(pid \\ __MODULE__) do
    GenServer.call(pid, :export)
  end

  # Server

  @impl true
  def init(opts) do
    table = :ets.new(:event_store, [:ordered_set, :private])

    state = %__MODULE__{
      table: table,
      chain: opts[:chain],
      max_events: opts[:max_events] || 100_000,
      persist_path: opts[:persist_path]
    }

    # Load from disk if path exists
    if state.persist_path && File.exists?(state.persist_path) do
      load_from_disk(state)
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:store, event}, _from, state) do
    key = generate_key(event)
    :ets.insert(state.table, {key, event})
    maybe_evict(state)
    maybe_persist(state)
    {:reply, {:ok, key}, state}
  end

  @impl true
  def handle_call({:store_batch, events}, _from, state) do
    keys = Enum.map(events, fn event ->
      key = generate_key(event)
      :ets.insert(state.table, {key, event})
      key
    end)
    maybe_evict(state)
    maybe_persist(state)
    {:reply, {:ok, keys}, state}
  end

  @impl true
  def handle_call({:query, filters}, _from, state) do
    events = :ets.tab2list(state.table)
      |> Enum.map(fn {_key, event} -> event end)
      |> apply_filters(filters)
      |> Enum.take(filters[:limit] || 100)
    {:reply, {:ok, events}, state}
  end

  @impl true
  def handle_call(:count, _from, state) do
    {:reply, :ets.info(state.table, :size), state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(state.table)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:export, _from, state) do
    events = :ets.tab2list(state.table) |> Enum.map(fn {_k, v} -> v end)
    {:reply, {:ok, events}, state}
  end

  @impl true
  def terminate(_reason, state) do
    maybe_persist(state)
    :ets.delete(state.table)
  end

  defp generate_key(event) do
    block = event[:block_number] || event.block_number || 0
    idx = event[:log_index] || event.log_index || System.unique_integer([:positive])
    {block, idx}
  end

  defp apply_filters(events, filters) do
    events
    |> maybe_filter_field(:type, filters[:type])
    |> maybe_filter_field(:address, filters[:address])
    |> maybe_filter_range(:block_number, filters[:from_block], filters[:to_block])
  end

  defp maybe_filter_field(events, _field, nil), do: events
  defp maybe_filter_field(events, field, value) do
    Enum.filter(events, &(Map.get(&1, field) == value))
  end

  defp maybe_filter_range(events, _field, nil, nil), do: events
  defp maybe_filter_range(events, field, from, to) do
    Enum.filter(events, fn event ->
      val = Map.get(event, field, 0)
      (from == nil or val >= from) and (to == nil or val <= to)
    end)
  end

  defp maybe_evict(state) do
    size = :ets.info(state.table, :size)
    if size > state.max_events do
      # Remove oldest 10%
      to_remove = div(state.max_events, 10)
      :ets.tab2list(state.table)
      |> Enum.take(to_remove)
      |> Enum.each(fn {key, _} -> :ets.delete(state.table, key) end)
    end
  end

  defp maybe_persist(%{persist_path: nil}), do: :ok
  defp maybe_persist(state) do
    events = :ets.tab2list(state.table)
    binary = :erlang.term_to_binary(events)
    File.write(state.persist_path, binary)
  end

  defp load_from_disk(state) do
    case File.read(state.persist_path) do
      {:ok, binary} ->
        events = :erlang.binary_to_term(binary)
        Enum.each(events, fn entry -> :ets.insert(state.table, entry) end)
      _ -> :ok
    end
  end
end
