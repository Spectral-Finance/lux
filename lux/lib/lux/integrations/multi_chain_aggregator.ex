defmodule Lux.Integrations.MultiChainAggregator do
  @moduledoc """
  Multi-chain data aggregation engine for collecting and processing blockchain
  data across multiple EVM-compatible networks.

  Supports Ethereum, BSC, Polygon, Arbitrum, Optimism, Base, Avalanche, and Fantom.

  ## Features
  - Multi-chain RPC management with failover
  - Block and transaction monitoring
  - Smart contract event aggregation
  - Historical data indexing
  - Real-time data streaming via GenStage
  - Data normalization across chains
  - Configurable data retention
  - Query optimization with caching
  """

  alias Lux.Integrations.MultiChainAggregator.{
    RPCManager,
    BlockMonitor,
    EventAggregator,
    DataStore,
    Streamer,
    Normalizer,
    QueryEngine
  }

  @default_chains %{
    ethereum: %{
      rpc_urls: ["https://eth.llamarpc.com", "https://rpc.ankr.com/eth"],
      chain_id: 1,
      block_time: 12_000,
      start_block: nil
    },
    bsc: %{
      rpc_urls: ["https://bsc-dataseed.binance.org", "https://rpc.ankr.com/bsc"],
      chain_id: 56,
      block_time: 3_000,
      start_block: nil
    },
    polygon: %{
      rpc_urls: ["https://polygon-rpc.com", "https://rpc.ankr.com/polygon"],
      chain_id: 137,
      block_time: 2_000,
      start_block: nil
    },
    arbitrum: %{
      rpc_urls: ["https://arb1.arbitrum.io/rpc", "https://rpc.ankr.com/arbitrum"],
      chain_id: 42161,
      block_time: 1_200,
      start_block: nil
    },
    optimism: %{
      rpc_urls: ["https://mainnet.optimism.io", "https://rpc.ankr.com/optimism"],
      chain_id: 10,
      block_time: 2_000,
      start_block: nil
    },
    base: %{
      rpc_urls: ["https://mainnet.base.org", "https://rpc.ankr.com/base"],
      chain_id: 8453,
      block_time: 2_000,
      start_block: nil
    },
    avalanche: %{
      rpc_urls: ["https://api.avax.network/ext/bc/C/rpc"],
      chain_id: 43114,
      block_time: 2_000,
      start_block: nil
    },
    fantom: %{
      rpc_urls: ["https://rpc.ftm.tools"],
      chain_id: 250,
      block_time: 1_000,
      start_block: nil
    }
  }

  @type chain :: atom()
  @type chain_config :: map()
  @type block_data :: map()
  @type tx_data :: map()
  @type event_data :: map()
  @type query_result :: map()

  @doc "Start monitoring all configured chains"
  def start_monitoring(chains \ nil, opts \\ []) do
    active_chains = chains || Map.keys(@default_chains)
    
    results = Enum.map(active_chains, fn chain ->
      case start_chain(chain, opts) do
        {:ok, pid} -> {chain, {:ok, pid}}
        {:error, reason} -> {chain, {:error, reason}}
      end
    end)

    {:ok, results}
  end

  defp start_chain(chain, opts) do
    config = get_chain_config(chain)
    |> Map.merge(Enum.into(opts, %{}))

    with {:ok, rpc_pid} <- RPCManager.start_link(chain, config),
         {:ok, monitor_pid} <- BlockMonitor.start_link(chain, config, rpc_pid),
         {:ok, agg_pid} <- EventAggregator.start_link(chain, config),
         {:ok, stream_pid} <- Streamer.start_link(chain, config) do
      {:ok, %{rpc: rpc_pid, monitor: monitor_pid, aggregator: agg_pid, streamer: stream_pid}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Get chain configuration"
  def get_chain_config(chain) do
    Map.get(@default_chains, chain, %{})
  end

  @doc "Fetch latest block from a chain"
  def get_latest_block(chain) do
    RPCManager.call(chain, "eth_blockNumber", [])
    |> parse_hex_int()
  end

  @doc "Fetch block by number"
  def get_block(chain, block_number, full_tx \\ false) do
    params = [to_hex(block_number), full_tx]
    RPCManager.call(chain, "eth_getBlockByNumber", params)
    |> Normalizer.normalize_block(chain)
  end

  @doc "Fetch transaction by hash"
  def get_transaction(chain, tx_hash) do
    RPCManager.call(chain, "eth_getTransactionByHash", [tx_hash])
    |> Normalizer.normalize_transaction(chain)
  end

  @doc "Fetch transaction receipt"
  def get_transaction_receipt(chain, tx_hash) do
    RPCManager.call(chain, "eth_getTransactionReceipt", [tx_hash])
    |> Normalizer.normalize_receipt(chain)
  end

  @doc "Query contract events across chains"
  def query_events(chains, contract_address, event_sig, from_block, to_block) do
    chains
    |> Enum.map(fn chain ->
      Task.async(fn ->
        logs = RPCManager.call(chain, "eth_getLogs", [
          %{fromBlock: to_hex(from_block), toBlock: to_hex(to_block),
            address: contract_address, topics: [event_sig]}
        ])
        {chain, Normalizer.normalize_logs(logs, chain)}
      end)
    end)
    |> Task.await_many(30_000)
    |> Enum.into(%{})
  end

  @doc "Stream real-time blocks from a chain"
  def stream_blocks(chain, callback, opts \\ []) do
    interval = get_chain_config(chain).block_time
    last_block = get_latest_block(chain)

    Stream.interval(interval)
    |> Stream.map(fn _ -> get_latest_block(chain) end)
    |> Stream.filter(fn block -> block > last_block end)
    |> Stream.each(fn block ->
      block_data = get_block(chain, block, true)
      callback.(chain, block_data)
    end)
    |> Stream.run()
  end

  @doc "Aggregate data across chains with query engine"
  def aggregate_query(query) do
    QueryEngine.execute(query)
  end

  defp parse_hex_int("0x" <> hex), do: String.to_integer(hex, 16)
  defp parse_hex_int(hex) when is_binary(hex), do: String.to_integer(hex, 16)
  defp parse_hex_int(val) when is_integer(val), do: val

  defp to_hex(int) when is_integer(int), do: "0x" <> Integer.to_string(int, 16)
end