defmodule Lux.Web3.MultiChainAggregator do
  @moduledoc """
  Multi-Chain Data Aggregation Engine for collecting, normalizing, caching,
  and querying blockchain blocks, transactions, and smart contract events
  across EVM-compatible networks (Ethereum, Base, Arbitrum, Optimism, Polygon, BSC).
  """

  use GenServer
  require Logger

  @type chain_id :: pos_integer()
  @type chain_config :: %{
          chain_id: chain_id(),
          name: String.t(),
          rpc_urls: [String.t()],
          rate_limit_per_sec: pos_integer(),
          retention_seconds: pos_integer()
        }

  @type normalized_block :: %{
          chain_id: chain_id(),
          block_number: non_neg_integer(),
          block_hash: String.t(),
          parent_hash: String.t(),
          timestamp: non_neg_integer(),
          transaction_count: non_neg_integer()
        }

  @type normalized_event :: %{
          chain_id: chain_id(),
          block_number: non_neg_integer(),
          tx_hash: String.t(),
          contract_address: String.t(),
          topic0: String.t(),
          topics: [String.t()],
          data: String.t(),
          log_index: non_neg_integer(),
          ingested_at: integer()
        }

  @default_chains %{
    1 => %{chain_id: 1, name: "ethereum", rpc_urls: ["https://eth.llamarpc.com"], rate_limit_per_sec: 25, retention_seconds: 86_400},
    8453 => %{chain_id: 8453, name: "base", rpc_urls: ["https://mainnet.base.org"], rate_limit_per_sec: 25, retention_seconds: 86_400},
    137 => %{chain_id: 137, name: "polygon", rpc_urls: ["https://polygon-rpc.com"], rate_limit_per_sec: 20, retention_seconds: 86_400},
    56 => %{chain_id: 56, name: "bsc", rpc_urls: ["https://bsc-dataseed.binance.org"], rate_limit_per_sec: 20, retention_seconds: 86_400},
    42161 => %{chain_id: 42161, name: "arbitrum", rpc_urls: ["https://arb1.arbitrum.io/rpc"], rate_limit_per_sec: 25, retention_seconds: 86_400}
  }

  # ── Client API ─────────────────────────────────────────────────

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Register or update an EVM chain RPC configuration."
  def register_chain(server \\ __MODULE__, config) when is_map(config) do
    GenServer.call(server, {:register_chain, config})
  end

  @doc "Normalize a raw JSON-RPC eth_getBlockByNumber payload into a canonical cross-chain block."
  def normalize_block(chain_id, raw_block) when is_integer(chain_id) and is_map(raw_block) do
    txs = Map.get(raw_block, "transactions", [])
    %{
      chain_id: chain_id,
      block_number: parse_hex_int(Map.get(raw_block, "number", "0x0")),
      block_hash: String.downcase(to_string(Map.get(raw_block, "hash", ""))),
      parent_hash: String.downcase(to_string(Map.get(raw_block, "parentHash", ""))),
      timestamp: parse_hex_int(Map.get(raw_block, "timestamp", "0x0")),
      transaction_count: if(is_list(txs), do: length(txs), else: 0)
    }
  end

  @doc "Normalize a raw JSON-RPC eth_getLogs entry into a canonical cross-chain event."
  def normalize_event(chain_id, raw_log) when is_integer(chain_id) and is_map(raw_log) do
    topics = Map.get(raw_log, "topics", [])
    %{
      chain_id: chain_id,
      block_number: parse_hex_int(Map.get(raw_log, "blockNumber", "0x0")),
      tx_hash: String.downcase(to_string(Map.get(raw_log, "transactionHash", ""))),
      contract_address: String.downcase(to_string(Map.get(raw_log, "address", ""))),
      topic0: List.first(topics) || "",
      topics: topics,
      data: Map.get(raw_log, "data", "0x"),
      log_index: parse_hex_int(Map.get(raw_log, "logIndex", "0x0")),
      ingested_at: System.system_time(:second)
    }
  end

  @doc "Ingest normalized blocks or contract events into the aggregation store."
  def ingest_blocks(server \\ __MODULE__, chain_id, raw_blocks) when is_list(raw_blocks) do
    GenServer.call(server, {:ingest_blocks, chain_id, raw_blocks})
  end

  def ingest_events(server \\ __MODULE__, chain_id, raw_logs) when is_list(raw_logs) do
    GenServer.call(server, {:ingest_events, chain_id, raw_logs})
  end

  @doc "Query aggregated events across one or multiple chains with filtering and limit."
  def query_events(server \\ __MODULE__, filters \\ %{}) do
    GenServer.call(server, {:query_events, filters})
  end

  @doc "Query aggregated blocks across chains."
  def query_blocks(server \\ __MODULE__, filters \\ %{}) do
    GenServer.call(server, {:query_blocks, filters})
  end

  @doc "Evict expired historical records according to each chain's retention policy."
  def prune_expired(server \\ __MODULE__, now_sec \\ System.system_time(:second)) do
    GenServer.call(server, {:prune_expired, now_sec})
  end

  # ── Server Callbacks ───────────────────────────────────────────

  @impl true
  def init(opts) do
    chains = Keyword.get(opts, :chains, @default_chains)
    state = %{
      chains: chains,
      blocks: [],
      events: [],
      subscriptions: %{}
    }
    {:ok, state}
  end

  @impl true
  def handle_call({:register_chain, config}, _from, state) do
    updated = Map.put(state.chains, config.chain_id, config)
    {:reply, :ok, %{state | chains: updated}}
  end

  @impl true
  def handle_call({:ingest_blocks, chain_id, raw_blocks}, _from, state) do
    normalized = Enum.map(raw_blocks, &normalize_block(chain_id, &1))
    merged =
      (normalized ++ state.blocks)
      |> Enum.uniq_by(fn b -> {b.chain_id, b.block_number, b.block_hash} end)
      |> Enum.sort_by(fn b -> {b.timestamp, b.block_number} end, :desc)

    {:reply, {:ok, length(normalized)}, %{state | blocks: merged}}
  end

  @impl true
  def handle_call({:ingest_events, chain_id, raw_logs}, _from, state) do
    normalized = Enum.map(raw_logs, &normalize_event(chain_id, &1))
    merged =
      (normalized ++ state.events)
      |> Enum.uniq_by(fn e -> {e.chain_id, e.tx_hash, e.log_index} end)
      |> Enum.sort_by(fn e -> {e.block_number, e.log_index} end, :desc)

    {:reply, {:ok, length(normalized)}, %{state | events: merged}}
  end

  @impl true
  def handle_call({:query_events, filters}, _from, state) do
    limit = Map.get(filters, :limit, 100)
    results =
      state.events
      |> Enum.filter(&matches_event_filter?(&1, filters))
      |> Enum.take(limit)

    {:reply, {:ok, results}, state}
  end

  @impl true
  def handle_call({:query_blocks, filters}, _from, state) do
    limit = Map.get(filters, :limit, 100)
    results =
      state.blocks
      |> Enum.filter(&matches_block_filter?(&1, filters))
      |> Enum.take(limit)

    {:reply, {:ok, results}, state}
  end

  @impl true
  def handle_call({:prune_expired, now_sec}, _from, state) do
    kept_events =
      Enum.filter(state.events, fn ev ->
        retention = get_in(state.chains, [ev.chain_id, :retention_seconds]) || 86_400
        now_sec - ev.ingested_at <= retention
      end)

    pruned_count = length(state.events) - length(kept_events)
    {:reply, {:ok, pruned_count}, %{state | events: kept_events}}
  end

  # ── Internal Helpers ───────────────────────────────────────────

  defp matches_event_filter?(ev, filters) do
    chain_ok =
      case Map.get(filters, :chain_ids) do
        nil -> true
        ids when is_list(ids) -> ev.chain_id in ids
      end

    contract_ok =
      case Map.get(filters, :contract_address) do
        nil -> true
        addr -> ev.contract_address == String.downcase(addr)
      end

    topic_ok =
      case Map.get(filters, :topic0) do
        nil -> true
        t0 -> ev.topic0 == t0
      end

    min_block_ok =
      case Map.get(filters, :from_block) do
        nil -> true
        fb -> ev.block_number >= fb
      end

    chain_ok and contract_ok and topic_ok and min_block_ok
  end

  defp matches_block_filter?(blk, filters) do
    case Map.get(filters, :chain_ids) do
      nil -> true
      ids when is_list(ids) -> blk.chain_id in ids
    end
  end

  defp parse_hex_int("0x" <> hex) do
    case Integer.parse(hex, 16) do
      {val, ""} -> val
      _ -> 0
    end
  end

  defp parse_hex_int(val) when is_integer(val), do: val
  defp parse_hex_int(_), do: 0
end
