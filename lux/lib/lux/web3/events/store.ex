defmodule Lux.Web3.Events.Store do
  @moduledoc """
  Event persistence and retrieval system.

  Stores events in an ETS table for fast in-memory access with
  support for querying by contract, block range, event type,
  and timestamp. Events survive restarts via checkpoint/restore.
  """

  use GenServer

  # Client API

  @doc """
  Starts the event store.
  """
  @spec start_link([{:table_name, atom()}]) :: GenServer.on_start()
  def start_link(opts \ []) do
    name = opts[:name] || __MODULE__
    table_name = opts[:table_name] || :lux_event_store
    GenServer.start_link(__MODULE__, [table_name: table_name], name: name)
  end

  @doc """
  Saves a list of events to the store.
  """
  @spec save_events(GenServer.server(), [Lux.Web3.Events.Event.t()]) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def save_events(server \ __MODULE__, events) do
    GenServer.call(server, {:save, events})
  end

  @doc """
  Saves a single event to the store.
  """
  @spec save_event(GenServer.server(), Lux.Web3.Events.Event.t()) :: :ok
  def save_event(server \ __MODULE__, event) do
    GenServer.call(server, {:save, [event]})
    :ok
  end

  @doc """
  Retrieves events for a specific contract address.
  """
  @spec get_events_for_contract(GenServer.server(), String.t()) :: [Lux.Web3.Events.Event.t()]
  def get_events_for_contract(server \ __MODULE__, contract_address) do
    GenServer.call(server, {:query, %{contract: contract_address}})
  end

  @doc """
  Retrieves events within a block range.
  """
  @spec get_events_in_block_range(
          GenServer.server(),
          pos_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: [Lux.Web3.Events.Event.t()]
  def get_events_in_block_range(server \ __MODULE__, chain_id, from_block, to_block) do
    GenServer.call(server, {:query, %{chain_id: chain_id, from_block: from_block, to_block: to_block}})
  end

  @doc """
  Retrieves events by topic0 (event signature hash).
  """
  @spec get_events_by_topic(GenServer.server(), String.t()) :: [Lux.Web3.Events.Event.t()]
  def get_events_by_topic(server \ __MODULE__, topic0) do
    GenServer.call(server, {:query, %{topic0: topic0}})
  end

  @doc """
  Retrieves the N most recent events.
  """
  @spec get_recent_events(GenServer.server(), non_neg_integer()) :: [Lux.Web3.Events.Event.t()]
  def get_recent_events(server \ __MODULE__, limit \ 50) do
    GenServer.call(server, {:recent, limit})
  end

  @doc """
  Gets event count statistics.
  """
  @spec stats(GenServer.server()) :: map()
  def stats(server \ __MODULE__) do
    GenServer.call(server, :stats)
  end

  @doc """
  Persists the current store to disk as a JSON checkpoint.
  """
  @spec checkpoint(GenServer.server(), String.t()) :: :ok | {:error, term()}
  def checkpoint(server \ __MODULE__, path \ "priv/web3/events_checkpoint.json") do
    GenServer.call(server, {:checkpoint, path})
  end

  @doc """
  Restores the store from a checkpoint file.
  """
  @spec restore(GenServer.server(), String.t()) :: :ok | {:error, term()}
  def restore(server \ __MODULE__, path \ "priv/web3/events_checkpoint.json") do
    GenServer.call(server, {:restore, path})
  end

  @doc """
  Clears all events from the store.
  """
  @spec clear(GenServer.server()) :: :ok
  def clear(server \ __MODULE__) do
    GenServer.call(server, :clear)
  end

  # Server callbacks

  @impl true
  def init([table_name: tn]) do
    table = :ets.new(tn, [:set, :named_table, :read_access, :compressed])
    {:ok, %{table: table, count: 0}}
  end

  @impl true
  def handle_call({:save, events}, _from, %{table: table} = state) do
    saved =
      Enum.reduce(events, 0, fn event, count ->
        :ets.insert(table, {event.block_number, event.log_index, Event.to_map(event)})
        count + 1
      end)

    {:reply, {:ok, saved}, %{state | count: state.count + saved}}
  end

  def handle_call({:query, opts}, _from, %{table: table} = state) do
    results = query_events(table, opts)
    {:reply, {:ok, results}, state}
  end

  def handle_call({:recent, limit}, _from, %{table: table} = state) do
    results =
      :ets.select(table, [{%{block_number: :"$1", log_index: :"$2", "_": :"$3"}, [], [:"$3"]}])
      |> Enum.sort_by(fn {bn, _li, _data} -> {-bn, -li} end)
      |> Enum.take(limit)
      |> Enum.map(fn {_bn, _li, data} ->
        map_to_event(data)
      end)

    {:reply, {:ok, results}, state}
  end

  def handle_call(:stats, _from, %{table: table, count: total} = state) do
    contracts =
      :ets.select(table, [{{:_, :_, %{contract_address: :"$1"}}, [], [:"$1"]}])
      |> Enum.uniq()

    events_by_contract =
      contracts
      |> Enum.map(fn addr ->
        count = :ets.select_count(table, [{%{contract_address: addr}, [], [true]}])
        {addr, count}
      end)
      |> Map.new()

    {:reply, {:ok, %{total: total, contracts: length(contracts), by_contract: events_by_contract}}, state}
  end

  def handle_call({:checkpoint, path}, _from, %{table: table} = state) do
    events =
      :ets.tab2list(table)
      |> Enum.map(fn {_bn, _li, data} -> data end)

    case File.write(path, Jason.encode!(events, pretty: true)) do
      :ok -> {:reply, :ok, state}
      error -> {:reply, error, state}
    end
  end

  def handle_call({:restore, path}, _from, %{table: table} = state) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, events} when is_list(events) ->
            :ets.delete_all_objects(table)

            Enum.each(events, fn event_map ->
              event = map_to_event(event_map)
              :ets.insert(table, {event.block_number, event.log_index, event_map})
            end)

            {:reply, :ok, %{state | count: length(events)}}

          _ ->
            {:reply, {:error, :invalid_checkpoint}, state}
        end

      {:error, _} ->
        {:reply, {:error, :file_not_found}, state}
    end
  end

  def handle_call(:clear, _from, %{table: table} = state) do
    :ets.delete_all_objects(table)
    {:reply, :ok, %{state | count: 0}}
  end

  # Query helpers

  defp query_events(table, %{contract: address}) do
    :ets.select(table, [{{%{contract_address: address}, :_, :"$1"}}, [], [:"$1"]])
    |> Enum.map(&map_to_event/1)
  end

  defp query_events(table, %{chain_id: cid, from_block: from, to_block: to}) do
    :ets.select(table, [
      {{%{block_number: from..to}, :_, :"$1"}},
      [],
      [:"$1"]
    ])
    |> Enum.map(&map_to_event/1)
  end

  defp query_events(table, %{topic0: topic}) do
    :ets.select(table, [
      {{%{topic0: topic}, :_, :"$1"}},
      [],
      [:"$1"]
    ])
    |> Enum.map(&map_to_event/1)
  end

  defp query_events(_table, _opts) do
    []
  end

  defp map_to_event(data) do
    chain_id = Map.get(data, "chain_id", 1)
    Event.from_raw(data, chain_id)
  end
end
