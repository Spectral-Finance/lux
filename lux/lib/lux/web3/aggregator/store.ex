defmodule Lux.Web3.Aggregator.Store do
  @moduledoc """
  Indexed multi-chain storage engine with configurable retention policies,
  query optimization, and cross-chain analytics for normalized blocks,
  transactions, and smart contract events.
  """

  alias Lux.Web3.Aggregator.Normalizer.NormalizedBlock
  alias Lux.Web3.Aggregator.Normalizer.NormalizedEvent
  alias Lux.Web3.Aggregator.Normalizer.NormalizedTransaction

  @blocks_table :lux_multichain_blocks
  @txs_table :lux_multichain_txs
  @events_table :lux_multichain_events
  @query_cache_table :lux_multichain_query_cache

  @doc """
  Initializes ETS tables for blocks, transactions, events, and query caching.
  """
  @spec ensure_started() :: :ok
  def ensure_started do
    ensure_table(@blocks_table, :ordered_set)
    ensure_table(@txs_table, :set)
    ensure_table(@events_table, :set)
    ensure_table(@query_cache_table, :set)
    :ok
  end

  @doc """
  Clears all stored multi-chain data and query caches.
  """
  @spec reset!() :: :ok
  def reset! do
    ensure_started()
    :ets.delete_all_objects(@blocks_table)
    :ets.delete_all_objects(@txs_table)
    :ets.delete_all_objects(@events_table)
    :ets.delete_all_objects(@query_cache_table)
    :ok
  end

  @doc """
  Stores a `%NormalizedBlock{}` and its embedded `%NormalizedTransaction{}` entries.
  """
  @spec put_block(NormalizedBlock.t()) :: :ok
  def put_block(%NormalizedBlock{} = block) do
    ensure_started()
    now_sec = System.system_time(:second)
    :ets.insert(@blocks_table, {{block.chain, block.block_number}, block, now_sec})

    Enum.each(block.transactions, fn %NormalizedTransaction{} = tx ->
      put_transaction(tx)
    end)

    invalidate_query_cache()
    :ok
  end

  @doc """
  Stores a `%NormalizedTransaction{}` entry.
  """
  @spec put_transaction(NormalizedTransaction.t()) :: :ok
  def put_transaction(%NormalizedTransaction{} = tx) do
    ensure_started()
    now_sec = System.system_time(:second)
    :ets.insert(@txs_table, {{tx.chain, tx.tx_hash}, tx, now_sec})
    :ok
  end

  @doc """
  Stores one or more `%NormalizedEvent{}` entries.
  """
  @spec put_events([NormalizedEvent.t()] | NormalizedEvent.t()) :: :ok
  def put_events(%NormalizedEvent{} = event), do: put_events([event])

  def put_events(events) when is_list(events) do
    ensure_started()
    now_sec = System.system_time(:second)

    Enum.each(events, fn %NormalizedEvent{} = event ->
      :ets.insert(@events_table, {event.id, event, now_sec})
    end)

    invalidate_query_cache()
    :ok
  end

  @doc """
  Queries stored blocks across chains with optional filters:
  `:chains`, `:from_block`, `:to_block`, `:limit`, and `:offset`.
  """
  @spec query_blocks(map() | keyword()) :: [NormalizedBlock.t()]
  def query_blocks(filters \\ %{}) do
    ensure_started()
    params = Map.new(filters)

    cached_query({:blocks, params}, fn ->
      @blocks_table
      |> :ets.tab2list()
      |> Enum.map(fn {_key, block, _stored_at} -> block end)
      |> Enum.filter(&block_matches?(&1, params))
      |> Enum.sort_by(&{&1.chain, &1.block_number}, :desc)
      |> paginate(params)
    end)
  end

  @doc """
  Queries stored transactions across chains with optional filters:
  `:chains`, `:from`, `:to`, `:min_value_wei`, `:from_block`, `:to_block`, `:limit`, `:offset`.
  """
  @spec query_transactions(map() | keyword()) :: [NormalizedTransaction.t()]
  def query_transactions(filters \\ %{}) do
    ensure_started()
    params = Map.new(filters)

    cached_query({:txs, params}, fn ->
      @txs_table
      |> :ets.tab2list()
      |> Enum.map(fn {_key, tx, _stored_at} -> tx end)
      |> Enum.filter(&tx_matches?(&1, params))
      |> Enum.sort_by(&{&1.block_number, &1.tx_hash}, :desc)
      |> paginate(params)
    end)
  end

  @doc """
  Queries stored smart contract events across chains with optional filters:
  `:chains`, `:contract_address`, `:event_name`, `:topic0`, `:from_block`, `:to_block`,
  `:limit`, and `:offset`.
  """
  @spec query_events(map() | keyword()) :: [NormalizedEvent.t()]
  def query_events(filters \\ %{}) do
    ensure_started()
    params = Map.new(filters)

    cached_query({:events, params}, fn ->
      @events_table
      |> :ets.tab2list()
      |> Enum.map(fn {_id, event, _stored_at} -> event end)
      |> Enum.filter(&event_matches?(&1, params))
      |> Enum.sort_by(&{&1.block_number, &1.log_index}, :desc)
      |> paginate(params)
    end)
  end

  @doc """
  Computes cross-chain aggregated summary statistics across indexed blocks,
  transactions, and events.
  """
  @spec summary_stats() :: map()
  def summary_stats do
    ensure_started()
    blocks = Enum.map(:ets.tab2list(@blocks_table), &elem(&1, 1))
    txs = Enum.map(:ets.tab2list(@txs_table), &elem(&1, 1))
    events = Enum.map(:ets.tab2list(@events_table), &elem(&1, 1))

    chains =
      (Enum.map(blocks, & &1.chain) ++ Enum.map(events, & &1.chain))
      |> Enum.uniq()

    per_chain =
      Map.new(chains, fn chain ->
        chain_blocks = Enum.filter(blocks, &(&1.chain == chain))
        chain_txs = Enum.filter(txs, &(&1.chain == chain))
        chain_events = Enum.filter(events, &(&1.chain == chain))

        latest_block =
          case Enum.max_by(chain_blocks, & &1.block_number, fn -> nil end) do
            nil -> 0
            b -> b.block_number
          end

        {chain,
         %{
           block_count: length(chain_blocks),
           latest_block: latest_block,
           transaction_count: length(chain_txs),
           event_count: length(chain_events)
         }}
      end)

    %{
      total_blocks: length(blocks),
      total_transactions: length(txs),
      total_events: length(events),
      chains: per_chain
    }
  end

  @doc """
  Enforces data retention policies (`:max_blocks_per_chain`, `:max_events`, `:ttl_seconds`),
  evicting stale or excess records.
  """
  @spec enforce_retention(map() | keyword()) :: %{
          pruned_blocks: non_neg_integer(),
          pruned_events: non_neg_integer()
        }
  def enforce_retention(opts \\ %{}) do
    ensure_started()
    params = Map.new(opts)
    now_sec = System.system_time(:second)
    ttl_sec = Map.get(params, :ttl_seconds)
    max_blocks = Map.get(params, :max_blocks_per_chain)
    max_events = Map.get(params, :max_events)

    pruned_blocks = prune_blocks(now_sec, ttl_sec, max_blocks)
    pruned_events = prune_events(now_sec, ttl_sec, max_events)
    invalidate_query_cache()

    %{pruned_blocks: pruned_blocks, pruned_events: pruned_events}
  end

  defp prune_blocks(now_sec, ttl_sec, max_blocks) do
    entries = :ets.tab2list(@blocks_table)

    ttl_pruned =
      if is_integer(ttl_sec) do
        Enum.reduce(entries, 0, fn {key, _block, stored_at}, acc ->
          if now_sec - stored_at >= ttl_sec do
            :ets.delete(@blocks_table, key)
            acc + 1
          else
            acc
          end
        end)
      else
        0
      end

    cap_pruned =
      if is_integer(max_blocks) and max_blocks >= 0 do
        @blocks_table
        |> :ets.tab2list()
        |> Enum.group_by(fn {{chain, _num}, _block, _ts} -> chain end)
        |> Enum.reduce(0, fn {_chain, group}, acc ->
          sorted = Enum.sort_by(group, fn {{_c, num}, _b, _ts} -> num end, :desc)
          overflow = Enum.drop(sorted, max_blocks)

          Enum.each(overflow, fn {key, _b, _ts} -> :ets.delete(@blocks_table, key) end)
          acc + length(overflow)
        end)
      else
        0
      end

    ttl_pruned + cap_pruned
  end

  defp prune_events(now_sec, ttl_sec, max_events) do
    entries = :ets.tab2list(@events_table)

    ttl_pruned =
      if is_integer(ttl_sec) do
        Enum.reduce(entries, 0, fn {id, _event, stored_at}, acc ->
          if now_sec - stored_at >= ttl_sec do
            :ets.delete(@events_table, id)
            acc + 1
          else
            acc
          end
        end)
      else
        0
      end

    cap_pruned =
      if is_integer(max_events) and max_events >= 0 do
        remaining = :ets.tab2list(@events_table)

        sorted =
          Enum.sort_by(
            remaining,
            fn {_id, ev, _ts} -> {ev.block_number, ev.log_index} end,
            :desc
          )

        overflow = Enum.drop(sorted, max_events)
        Enum.each(overflow, fn {id, _ev, _ts} -> :ets.delete(@events_table, id) end)
        length(overflow)
      else
        0
      end

    ttl_pruned + cap_pruned
  end

  defp block_matches?(block, params) do
    chains = Map.get(params, :chains)
    from_block = Map.get(params, :from_block)
    to_block = Map.get(params, :to_block)

    (is_nil(chains) or block.chain in List.wrap(chains)) and
      (is_nil(from_block) or block.block_number >= from_block) and
      (is_nil(to_block) or block.block_number <= to_block)
  end

  defp tx_matches?(tx, params) do
    chains = Map.get(params, :chains)
    from_addr = downcase_opt(Map.get(params, :from))
    to_addr = downcase_opt(Map.get(params, :to))
    min_val = Map.get(params, :min_value_wei)
    from_block = Map.get(params, :from_block)
    to_block = Map.get(params, :to_block)

    (is_nil(chains) or tx.chain in List.wrap(chains)) and
      (is_nil(from_addr) or tx.from == from_addr) and
      (is_nil(to_addr) or tx.to == to_addr) and
      (is_nil(min_val) or tx.value_wei >= min_val) and
      (is_nil(from_block) or tx.block_number >= from_block) and
      (is_nil(to_block) or tx.block_number <= to_block)
  end

  defp event_matches?(event, params) do
    chains = Map.get(params, :chains)
    contract = downcase_opt(Map.get(params, :contract_address))
    event_name = Map.get(params, :event_name)
    topic0 = downcase_opt(Map.get(params, :topic0))
    from_block = Map.get(params, :from_block)
    to_block = Map.get(params, :to_block)

    (is_nil(chains) or event.chain in List.wrap(chains)) and
      (is_nil(contract) or event.contract_address == contract) and
      (is_nil(event_name) or event.event_name == event_name) and
      (is_nil(topic0) or event.topic0 == topic0) and
      (is_nil(from_block) or event.block_number >= from_block) and
      (is_nil(to_block) or event.block_number <= to_block)
  end

  defp paginate(list, params) do
    offset = Map.get(params, :offset, 0)
    dropped = Enum.drop(list, offset)

    case Map.get(params, :limit) do
      limit when is_integer(limit) and limit >= 0 -> Enum.take(dropped, limit)
      _ -> dropped
    end
  end

  defp cached_query(key, fun) do
    case :ets.lookup(@query_cache_table, key) do
      [{^key, result}] ->
        result

      [] ->
        result = fun.()
        :ets.insert(@query_cache_table, {key, result})
        result
    end
  end

  defp invalidate_query_cache do
    if :ets.whereis(@query_cache_table) != :undefined do
      :ets.delete_all_objects(@query_cache_table)
    end
  end

  defp downcase_opt(nil), do: nil
  defp downcase_opt(val) when is_binary(val), do: String.downcase(val)

  defp ensure_table(name, kind) do
    case :ets.whereis(name) do
      :undefined ->
        try do
          :ets.new(name, [:named_table, :public, kind, read_concurrency: true])
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end
  end
end
