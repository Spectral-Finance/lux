defmodule Lux.Web3.StorageEngine do
  @moduledoc """
  Storage engine with configurable retention TTL for indexed multi-chain EVM data.
  Supports storing and querying blocks, transactions, and event logs.
  """

  use GenServer
  alias Lux.Web3.DataNormalizer

  @default_name __MODULE__
  @default_ttl 86400 # 24 hours in seconds
  @prune_interval 300_000 # Prune every 5 minutes

  # ETS Table Names
  @blocks_table :lux_storage_engine_blocks
  @txs_table :lux_storage_engine_txs
  @logs_table :lux_storage_engine_logs

  # Client API

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @default_name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Stores raw or normalized multi-chain item(s) (block, transaction, log) in the storage engine.
  Options can specify custom `:ttl` in seconds.
  """
  def store(server \\ @default_name, chain, type, data, opts \\ [])

  def store(server, chain, type, data, opts) when is_list(data) do
    Enum.each(data, fn item -> store(server, chain, type, item, opts) end)
    :ok
  end

  def store(server, chain, type, data, opts) when is_map(data) do
    GenServer.call(server, {:store, chain, type, data, opts})
  end

  @doc """
  Fetches an item by chain, type, and identifier/key.
  For blocks: key can be block number or hash.
  For txs: key is tx hash.
  For logs: key is tx hash or log_index tuple.
  """
  def fetch(server \\ @default_name, chain, type, key) do
    GenServer.call(server, {:fetch, chain, type, key})
  end

  @doc """
  Queries items for a given chain and type matching filter conditions.
  Filters support: `:from_block`, `:to_block`, `:address`, `:topic`, `:limit`.
  """
  def query(server \\ @default_name, opts \\ []) do
    GenServer.call(server, {:query, opts})
  end

  @doc """
  Prunes items older than specified TTL seconds (or default configured TTL).
  """
  def prune_expired(server \\ @default_name, ttl_seconds \\ nil) do
    GenServer.call(server, {:prune_expired, ttl_seconds})
  end

  @doc """
  Clears all stored data from ETS tables.
  """
  def clear(server \\ @default_name) do
    GenServer.call(server, :clear)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    ttl = Keyword.get(opts, :ttl, Application.get_env(:lux, :storage_ttl_seconds, @default_ttl))

    blocks_table = :ets.new(@blocks_table, [:set, :public, :named_table, read_concurrency: true])
    txs_table = :ets.new(@txs_table, [:set, :public, :named_table, read_concurrency: true])
    logs_table = :ets.new(@logs_table, [:bag, :public, :named_table, read_concurrency: true])

    :timer.send_interval(@prune_interval, :scheduled_prune)

    {:ok, %{ttl: ttl, blocks: blocks_table, txs: txs_table, logs: logs_table}}
  end

  @impl true
  def handle_call({:store, chain, type, data, opts}, _from, state) do
    now = System.system_time(:second)
    ttl = Keyword.get(opts, :ttl, state.ttl)
    expires_at = now + ttl

    case normalize_type(type) do
      :block ->
        block = DataNormalizer.normalize_block(data, chain)

        if block.number != nil do
          # Index by number and by hash
          :ets.insert(state.blocks, {{block.chain, block.number}, block, expires_at})

          if block.hash != nil do
            :ets.insert(state.blocks, {{block.chain, block.hash}, block, expires_at})
          end
        end

      :transaction ->
        tx = DataNormalizer.normalize_transaction(data, chain)

        if tx.hash != nil do
          :ets.insert(state.txs, {{tx.chain, tx.hash}, tx, expires_at})
        end

      :log ->
        log = DataNormalizer.normalize_log(data, chain)
        :ets.insert(state.logs, {{log.chain, log.block_number}, log, expires_at})
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:fetch, chain, type, key}, _from, state) do
    normalized_chain = DataNormalizer.normalize_chain(chain)
    now = System.system_time(:second)

    result =
      case normalize_type(type) do
        :block ->
          lookup_and_filter_expired(state.blocks, {normalized_chain, key}, now)

        :transaction ->
          lookup_and_filter_expired(state.txs, {normalized_chain, key}, now)

        :log ->
          lookup_and_filter_expired(state.logs, {normalized_chain, key}, now)
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:query, opts}, _from, state) do
    now = System.system_time(:second)
    chain = opts |> Keyword.get(:chain) |> DataNormalizer.normalize_chain()
    type = normalize_type(Keyword.get(opts, :type, :block))
    from_block = Keyword.get(opts, :from_block)
    to_block = Keyword.get(opts, :to_block)
    address = DataNormalizer.normalize_address(Keyword.get(opts, :address))
    topic = DataNormalizer.normalize_hex_string(Keyword.get(opts, :topic))
    limit = Keyword.get(opts, :limit)

    table =
      case type do
        :block -> state.blocks
        :transaction -> state.txs
        :log -> state.logs
      end

    entries =
      :ets.tab2list(table)
      |> Enum.filter(fn {_key, item, expires_at} ->
        expires_at > now and
          item.chain == chain and
          filter_block_range(item, from_block, to_block) and
          filter_address(item, address) and
          filter_topic(item, topic)
      end)
      |> Enum.map(fn {_key, item, _exp} -> item end)
      |> Enum.uniq()

    results = if is_integer(limit) and limit > 0, do: Enum.take(entries, limit), else: entries

    {:reply, {:ok, results}, state}
  end

  @impl true
  def handle_call({:prune_expired, custom_ttl}, _from, state) do
    now = System.system_time(:second)
    prune_tables([state.blocks, state.txs, state.logs], now, custom_ttl)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(state.blocks)
    :ets.delete_all_objects(state.txs)
    :ets.delete_all_objects(state.logs)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:scheduled_prune, state) do
    now = System.system_time(:second)
    prune_tables([state.blocks, state.txs, state.logs], now, nil)
    {:noreply, state}
  end

  defp lookup_and_filter_expired(table, key, now) do
    case :ets.lookup(table, key) do
      [{^key, item, expires_at} | _] when expires_at > now ->
        {:ok, item}

      matches when is_list(matches) and matches != [] ->
        valid_items =
          matches
          |> Enum.filter(fn {_k, _item, exp} -> exp > now end)
          |> Enum.map(fn {_k, item, _exp} -> item end)

        case valid_items do
          [] -> {:error, :not_found}
          [single] -> {:ok, single}
          multiple -> {:ok, multiple}
        end

      _ ->
        {:error, :not_found}
    end
  end

  defp prune_tables(tables, now, custom_ttl) do
    Enum.each(tables, fn table ->
      :ets.foldl(
        fn {key, _item, expires_at}, acc ->
          if (custom_ttl && (now - expires_at + custom_ttl > 0)) or expires_at <= now do
            :ets.delete(table, key)
          end
          acc
        end,
        :ok,
        table
      )
    end)
  end

  defp filter_block_range(%{block_number: bn}, from_b, to_b) when is_integer(bn) do
    (is_nil(from_b) or bn >= from_b) and (is_nil(to_b) or bn <= to_b)
  end
  defp filter_block_range(%{number: bn}, from_b, to_b) when is_integer(bn) do
    (is_nil(from_b) or bn >= from_b) and (is_nil(to_b) or bn <= to_b)
  end
  defp filter_block_range(_, _, _), do: true

  defp filter_address(_item, nil), do: true
  defp filter_address(%{address: addr}, target) when is_binary(target), do: addr == target
  defp filter_address(%{from: from, to: to}, target) when is_binary(target), do: from == target or to == target
  defp filter_address(%{miner: miner}, target) when is_binary(target), do: miner == target
  defp filter_address(_, _), do: true

  defp filter_topic(_item, nil), do: true
  defp filter_topic(%{topics: topics}, target) when is_binary(target) and is_list(topics), do: Enum.member?(topics, target)
  defp filter_topic(_, _), do: true

  defp normalize_type(type) when type in [:block, "block", "blocks"], do: :block
  defp normalize_type(type) when type in [:transaction, :tx, "transaction", "tx", "transactions"], do: :transaction
  defp normalize_type(type) when type in [:log, :logs, "log", "logs", "event", "events"], do: :log
  defp normalize_type(_), do: :block
end
