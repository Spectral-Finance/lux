defmodule Lux.Memory.SimpleMemory do
  @moduledoc """
  A simple memory implementation using GenServer and ETS.
  Provides efficient chronological storage and retrieval of memory entries.
  """
  @behaviour Lux.Memory

  use GenServer

  defstruct [:name, :table, counter: 0]

  # Client API (Memory Behaviour)

  @impl Lux.Memory
  def initialize(opts) do
    name = opts[:name]
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl Lux.Memory
  def add(pid, content, type \\ :observation, metadata \\ %{}) do
    GenServer.call(pid, {:add, content, type, metadata})
  end

  @impl Lux.Memory
  def recent(pid, n) when is_integer(n) and n > 0 do
    GenServer.call(pid, {:recent, n})
  end

  @impl Lux.Memory
  def window(pid, start_time, end_time) do
    GenServer.call(pid, {:window, start_time, end_time})
  end

  @impl Lux.Memory
  def search(pid, query) do
    GenServer.call(pid, {:search, query})
  end

  # GenServer Callbacks

  @impl GenServer
  def init(opts) do
    # Create ETS table with ordered_set for chronological ordering
    table_name =
      case opts[:name] do
        nil -> :ets.new(__MODULE__, [:ordered_set, :protected])
        name -> :ets.new(name, [:ordered_set, :protected, :named_table])
      end

    {:ok,
     %__MODULE__{
       name: opts[:name],
       table: table_name,
       counter: 0
     }}
  end

  @impl GenServer
  def handle_call({:add, content, type, metadata}, _from, state) do
    timestamp = Map.get(metadata, :timestamp, System.system_time(:second))
    counter = state.counter

    entry = %{
      id: counter,
      content: content,
      type: type,
      timestamp: timestamp,
      metadata: metadata
    }

    # Use {timestamp, counter} as key for chronological ordering with uniqueness
    true = :ets.insert(state.table, {{counter, timestamp}, entry})

    {:reply, {:ok, entry}, %{state | counter: counter + 1}}
  end

  def handle_call({:recent, n}, _from, state) do
    result =
      case :ets.select_reverse(
             state.table,
             [
               {
                 {{:"$1", :"$2"}, :"$3"},
                 [],
                 [:"$3"]
               }
             ],
             n
           ) do
        :"$end_of_table" -> []
        {entries, _continuation} -> entries
      end

    {:reply, {:ok, result}, state}
  end

  def handle_call({:window, start_time, end_time}, _from, state) do
    start_ts = DateTime.to_unix(start_time)
    end_ts = DateTime.to_unix(end_time)

    result =
      :ets.select(state.table, [
        {
          {{:_, :"$1"}, :"$2"},
          [{:>=, :"$1", start_ts}, {:"=<", :"$1", end_ts}],
          [:"$2"]
        }
      ])

    {:reply, {:ok, result}, state}
  end

  def handle_call({:search, query}, _from, state) do
    pattern = String.downcase(query)

    result =
      state.table
      |> :ets.select([{{:_, :"$1"}, [], [:"$1"]}])
      |> Enum.filter(fn entry ->
        entry.content
        |> String.downcase()
        |> String.contains?(pattern)
      end)

    {:reply, {:ok, result}, state}
  end

  @impl GenServer
  def terminate(_reason, state) do
    :ets.delete(state.table)
    :ok
  end
end
