defmodule Lux.Web3.Aggregator do
  @moduledoc """
  Multi-Chain Data Aggregation Engine for collecting, normalizing, indexing,
  streaming, and querying blocks, transactions, and smart contract events
  across multiple EVM networks.
  """

  alias Lux.Web3.Aggregator.Normalizer
  alias Lux.Web3.Aggregator.RPCManager
  alias Lux.Web3.Aggregator.Store

  @subscribers_table :lux_multichain_subscribers

  @doc """
  Initializes RPC networks, indexed storage, and real-time subscriber tables.
  """
  @spec ensure_started() :: :ok
  def ensure_started do
    RPCManager.ensure_started()
    Store.ensure_started()
    ensure_subscriber_table()
    :ok
  end

  @doc """
  Resets all networks, stored records, and subscriptions.
  """
  @spec reset!() :: :ok
  def reset! do
    ensure_started()
    RPCManager.reset!()
    Store.reset!()
    :ets.delete_all_objects(@subscribers_table)
    :ok
  end

  @doc """
  Fetches, normalizes, indexes, and broadcasts the latest block (and its embedded
  transactions) across the specified EVM chains.
  """
  @spec sync_latest_blocks([atom()], keyword()) ::
          {:ok, %{blocks: [Normalizer.NormalizedBlock.t()], errors: map()}}
  def sync_latest_blocks(chains \\ [:ethereum, :polygon, :bsc, :arbitrum], opts \\ []) do
    ensure_started()
    include_txs = Keyword.get(opts, :include_transactions, true)

    {blocks, errors} =
      Enum.reduce(chains, {[], %{}}, fn chain, {ok_acc, err_acc} ->
        with {:ok, net} <- RPCManager.get_network(chain),
             {:ok, raw_block} when is_map(raw_block) <-
               RPCManager.call(chain, "eth_getBlockByNumber", ["latest", include_txs], opts) do
          normalized = Normalizer.normalize_block(net.id, net.chain_id, raw_block)
          Store.put_block(normalized)
          notify_subscribers(:block, normalized)
          {[normalized | ok_acc], err_acc}
        else
          {:error, reason} -> {ok_acc, Map.put(err_acc, chain, reason)}
          other -> {ok_acc, Map.put(err_acc, chain, {:invalid_block_response, other})}
        end
      end)

    {:ok, %{blocks: Enum.reverse(blocks), errors: errors}}
  end

  @doc """
  Indexes a historical block range (`from_block..to_block`) on a target EVM chain.
  """
  @spec index_block_range(atom(), non_neg_integer(), non_neg_integer(), keyword()) ::
          {:ok, [Normalizer.NormalizedBlock.t()]} | {:error, term()}
  def index_block_range(chain, from_block, to_block, opts \\ [])
      when is_integer(from_block) and is_integer(to_block) and from_block <= to_block do
    ensure_started()
    include_txs = Keyword.get(opts, :include_transactions, true)

    with {:ok, net} <- RPCManager.get_network(chain) do
      blocks =
        Enum.flat_map(from_block..to_block, fn num ->
          hex_num = Normalizer.int_to_hex(num)

          case RPCManager.call(chain, "eth_getBlockByNumber", [hex_num, include_txs], opts) do
            {:ok, raw_block} when is_map(raw_block) ->
              normalized = Normalizer.normalize_block(net.id, net.chain_id, raw_block)
              Store.put_block(normalized)
              notify_subscribers(:block, normalized)
              [normalized]

            _ ->
              []
          end
        end)

      {:ok, blocks}
    end
  end

  @doc """
  Collects, normalizes, indexes, and streams smart contract event logs (`eth_getLogs`)
  across one or more EVM chains.
  """
  @spec collect_events([atom()], map() | keyword(), keyword()) ::
          {:ok, %{events: [Normalizer.NormalizedEvent.t()], errors: map()}}
  def collect_events(chains, filter_opts \\ %{}, rpc_opts \\ []) when is_list(chains) do
    ensure_started()
    filter_map = Map.new(filter_opts)
    rpc_filter = build_eth_logs_filter(filter_map)

    {events, errors} =
      Enum.reduce(chains, {[], %{}}, fn chain, {ok_acc, err_acc} ->
        with {:ok, net} <- RPCManager.get_network(chain),
             {:ok, raw_logs} when is_list(raw_logs) <-
               RPCManager.call(chain, "eth_getLogs", [rpc_filter], rpc_opts) do
          normalized =
            Enum.map(raw_logs, &Normalizer.normalize_event(net.id, net.chain_id, &1))

          Store.put_events(normalized)
          Enum.each(normalized, &notify_subscribers(:event, &1))
          {ok_acc ++ normalized, err_acc}
        else
          {:error, reason} -> {ok_acc, Map.put(err_acc, chain, reason)}
          other -> {ok_acc, Map.put(err_acc, chain, {:invalid_logs_response, other})}
        end
      end)

    {:ok, %{events: events, errors: errors}}
  end

  @doc """
  Subscribes a process (defaults to `self()`) to real-time multi-chain updates.
  Subscribers receive `{:lux_multichain_update, topic, payload}` messages.
  """
  @spec subscribe(pid(), atom()) :: :ok
  def subscribe(pid \\ self(), topic \\ :all) when is_pid(pid) and is_atom(topic) do
    ensure_started()
    :ets.insert(@subscribers_table, {pid, topic})
    :ok
  end

  @doc """
  Unsubscribes a process from real-time multi-chain updates.
  """
  @spec unsubscribe(pid()) :: :ok
  def unsubscribe(pid \\ self()) when is_pid(pid) do
    ensure_started()
    :ets.delete(@subscribers_table, pid)
    :ok
  end

  defdelegate query_blocks(filters \\ %{}), to: Store
  defdelegate query_transactions(filters \\ %{}), to: Store
  defdelegate query_events(filters \\ %{}), to: Store
  defdelegate summary_stats(), to: Store
  defdelegate enforce_retention(opts \\ %{}), to: Store

  defp build_eth_logs_filter(filter_map) do
    base = %{
      "fromBlock" => format_block_bound(Map.get(filter_map, :from_block, "latest")),
      "toBlock" => format_block_bound(Map.get(filter_map, :to_block, "latest"))
    }

    base
    |> maybe_put(
      "address",
      Map.get(filter_map, :address) || Map.get(filter_map, :contract_address)
    )
    |> maybe_put("topics", Map.get(filter_map, :topics))
  end

  defp format_block_bound(num) when is_integer(num) and num >= 0, do: Normalizer.int_to_hex(num)
  defp format_block_bound(tag) when is_binary(tag), do: tag
  defp format_block_bound(_), do: "latest"

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)

  defp notify_subscribers(topic, payload) do
    ensure_subscriber_table()

    @subscribers_table
    |> :ets.tab2list()
    |> Enum.each(fn {pid, sub_topic} ->
      if Process.alive?(pid) and sub_topic in [:all, topic] do
        send(pid, {:lux_multichain_update, topic, payload})
      end
    end)
  end

  defp ensure_subscriber_table do
    case :ets.whereis(@subscribers_table) do
      :undefined ->
        try do
          :ets.new(@subscribers_table, [:named_table, :public, :bag, read_concurrency: true])
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end
  end
end
