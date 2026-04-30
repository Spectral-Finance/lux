defmodule Lux.DataAggregation do
  @moduledoc """
  Multi-Chain Data Aggregation Engine for collecting and processing blockchain data
  across multiple EVM-compatible networks.

  ## Features
  - Multi-chain RPC management with automatic failover
  - Real-time block and transaction monitoring
  - Smart contract event filtering and processing
  - Efficient data storage and retrieval with configurable retention
  - Query interface for aggregated data
  - Rate limiting and error handling
  - Data normalization across chains

  ## Usage

      # Start the aggregation engine
      Lux.DataAggregation.start_link(chains: [:ethereum, :polygon, :bsc])

      # Query aggregated data
      Lux.DataAggregation.query_blocks(:ethereum, from: 19000000, to: 19000100)

      # Subscribe to real-time events
      Lux.DataAggregation.subscribe(:ethereum, contract_address: "0x...")
  """

  use Supervisor

  alias Lux.DataAggregation.{RPCManager, BlockMonitor, EventAggregator, DataStore, Streamer, Normalizer}

  @supported_chains %{
    ethereum: [
      name: "Ethereum Mainnet",
      chain_id: 1,
      symbol: "ETH",
      default_rpc: "https://eth.llamarpc.com",
      explorer: "https://etherscan.io"
    ],
    polygon: [
      name: "Polygon Mainnet",
      chain_id: 137,
      symbol: "MATIC",
      default_rpc: "https://polygon-rpc.com",
      explorer: "https://polygonscan.com"
    ],
    bsc: [
      name: "BNB Smart Chain",
      chain_id: 56,
      symbol: "BNB",
      default_rpc: "https://bsc-dataseed.binance.org",
      explorer: "https://bscscan.com"
    ],
    arbitrum: [
      name: "Arbitrum One",
      chain_id: 42161,
      symbol: "ETH",
      default_rpc: "https://arb1.arbitrum.io/rpc",
      explorer: "https://arbiscan.io"
    ],
    optimism: [
      name: "Optimism",
      chain_id: 10,
      symbol: "ETH",
      default_rpc: "https://mainnet.optimism.io",
      explorer: "https://optimistic.etherscan.io"
    ],
    avalanche: [
      name: "Avalanche C-Chain",
      chain_id: 43114,
      symbol: "AVAX",
      default_rpc: "https://api.avax.network/ext/bc/C/rpc",
      explorer: "https://snowtrace.io"
    ],
    fantom: [
      name: "Fantom Opera",
      chain_id: 250,
      symbol: "FTM",
      default_rpc: "https://rpc.ftm.tools",
      explorer: "https://ftmscan.com"
    ]
  }

  def start_link(opts \\ []) do
    chains = Keyword.get(opts, :chains, [:ethereum, :polygon, :bsc])
    Supervisor.start_link(__MODULE__, chains, name: __MODULE__)
  end

  @impl true
  def init(chains) do
    children = [
      {RPCManager, [chains: chains]},
      {DataStore, []},
      {Streamer, []},
      {BlockMonitor, [chains: chains]},
      {EventAggregator, [chains: chains]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Returns the list of supported chains.
  """
  def supported_chains, do: @supported_chains

  @doc """
  Returns chain configuration for a given chain atom.
  """
  def chain_config(chain) when is_atom(chain) do
    Map.get(@supported_chains, chain)
  end

  @doc """
  Query blocks from a specific chain.
  """
  def query_blocks(chain, opts \\ []) do
    DataStore.query_blocks(chain, opts)
  end

  @doc """
  Query transactions from a specific chain.
  """
  def query_transactions(chain, opts \\ []) do
    DataStore.query_transactions(chain, opts)
  end

  @doc """
  Query events from a specific chain and contract.
  """
  def query_events(chain, contract_address, opts \\ []) do
    DataStore.query_events(chain, contract_address, opts)
  end

  @doc """
  Subscribe to real-time block updates.
  """
  def subscribe_blocks(chain, pid) do
    Streamer.subscribe_blocks(chain, pid)
  end

  @doc """
  Subscribe to real-time events for a contract.
  """
  def subscribe_events(chain, contract_address, pid) do
    Streamer.subscribe_events(chain, contract_address, pid)
  end

  @doc """
  Get aggregated statistics for a chain.
  """
  def chain_stats(chain) do
    DataStore.chain_stats(chain)
  end

  @doc """
  Normalize data from multiple chains into a unified format.
  """
  def normalize(data, source_chain, target_format \\ :unified) do
    Normalizer.normalize(data, source_chain, target_format)
  end
end
