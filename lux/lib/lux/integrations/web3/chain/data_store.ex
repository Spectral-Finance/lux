defmodule Lux.Integrations.Web3.Chain.DataStore do
  @moduledoc """
  Persistent data store for multi-chain blockchain data.

  Uses ETS for fast in-memory access with optional disk persistence.
  Stores blocks, transactions, and query results with automatic retention management.
  """

  use GenServer

  defstruct [:blocks_table, :txs_table, :chain, :max_blocks, :max_txs, :persist_dir]

  # Client API

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def store_block(pid \\ __MODULE__, block) do
    GenServer.call(pid, {:store_block, block})
  end

  def store_transaction(pid \\ __MODULE__, tx) do
    GenServer.call(pid, {:store_tx, tx})
  end

  def get_block(pid \\ __MODULE__, number) do
    GenServer.call(pid, {:get_block, number})
  end

  def get_transaction(pid \\ __MODULE__, hash) do
    GenServer.call(pid, {:get_tx, hash})
  end

  def query_blocks(pid \\ __MODULE__, filters \\ %{}) do
    GenServer.call(pid, {:query_blocks, filters})
  end

  def stats(pid \\ __MODULE__) do
    GenServer.call(pid, :stats)
  end

  def persist(pid \\ __MODULE__) do
    GenServer.call(pid, :persist)
  end

  # Server

  @impl true
  def init(opts) do
    state = %__MODULE__{
      blocks_table: :ets.new(:chain_blocks, [:ordered_set, :private]),
      txs_table: :ets.new(:chain_txs, [:set, :private]),
      chain: opts[:chain],
      max_blocks: opts[:max_blocks] || 10_000,
      max_txs: opts[:max_txs] || 50_000,
      persist_dir: opts[:persist_dir]
    }

    if state.persist_dir do
      File.mkdir_p!(state.persist_dir)
      load_from_disk(state)
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:store_block, block}, _from, state) do
    key = block[:number] || block.number
    :ets.insert(state.blocks_table, {key, block})
    maybe_evict_blocks(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:store_tx, tx}, _from, state) do
    key = tx[:hash] || tx.hash
    :ets.insert(state.txs_table, {key, tx})
    maybe_evict_txs(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get_block, number}, _from, state) do
    case :ets.lookup(state.blocks_table, number) do
      [{_, block}] -> {:reply, {:ok, block}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:get_tx, hash}, _from, state) do
    case :ets.lookup(state.txs_table, hash) do
      [{_, tx}] -> {:reply, {:ok, tx}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:query_blocks, filters}, _from, state) do
    blocks = :ets.tab2list(state.blocks_table)
      |> Enum.map(fn {_k, v} -> v end)
      |> apply_block_filters(filters)
      |> Enum.take(filters[:limit] || 100)
    {:reply, {:ok, blocks}, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    {:reply, %{
      chain: state.chain,
      blocks_stored: :ets.info(state.blocks_table, :size),
      txs_stored: :ets.info(state.txs_table, :size),
      max_blocks: state.max_blocks,
      max_txs: state.max_txs
    }, state}
  end

  @impl true
  def handle_call(:persist, _from, state) do
    do_persist(state)
    {:reply, :ok, state}
  end

  @impl true
  def terminate(_reason, state) do
    do_persist(state)
    :ets.delete(state.blocks_table)
    :ets.delete(state.txs_table)
  end

  defp apply_block_filters(blocks, filters) do
    blocks
    |> maybe_range(:number, filters[:from_block], filters[:to_block])
  end

  defp maybe_range(items, _field, nil, nil), do: items
  defp maybe_range(items, field, from, to) do
    Enum.filter(items, fn item ->
      val = Map.get(item, field, 0)
      (from == nil or val >= from) and (to == nil or val <= to)
    end)
  end

  defp maybe_evict_blocks(state) do
    size = :ets.info(state.blocks_table, :size)
    if size > state.max_blocks do
      to_remove = div(state.max_blocks, 10)
      :ets.tab2list(state.blocks_table) |> Enum.take(to_remove) |> Enum.each(fn {k, _} -> :ets.delete(state.blocks_table, k) end)
    end
  end

  defp maybe_evict_txs(state) do
    size = :ets.info(state.txs_table, :size)
    if size > state.max_txs do
      to_remove = div(state.max_txs, 10)
      :ets.tab2list(state.txs_table) |> Enum.take(to_remove) |> Enum.each(fn {k, _} -> :ets.delete(state.txs_table, k) end)
    end
  end

  defp do_persist(%{persist_dir: nil}), do: :ok
  defp do_persist(state) do
    blocks = :ets.tab2list(state.blocks_table)
    txs = :ets.tab2list(state.txs_table)
    File.write!(Path.join(state.persist_dir, "blocks.etf"), :erlang.term_to_binary(blocks))
    File.write!(Path.join(state.persist_dir, "txs.etf"), :erlang.term_to_binary(txs))
  end

  defp load_from_disk(state) do
    for {file, table} <- [{"blocks.etf", state.blocks_table}, {"txs.etf", state.txs_table}] do
      path = Path.join(state.persist_dir, file)
      if File.exists?(path) do
        data = File.read!(path) |> :erlang.binary_to_term()
        Enum.each(data, fn entry -> :ets.insert(table, entry) end)
      end
    end
  end
end
