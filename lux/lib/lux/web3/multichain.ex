defmodule Lux.Web3.Multichain do
  @moduledoc """
  Public API for the Multi-Chain Data Aggregation and Indexing Engine (#74).

  Provides a unified interface for:
  - Multi-chain RPC configuration and health monitoring
  - Ingestion and normalization of blocks, transactions, and event logs
  - Multi-chain querying and historical data indexing
  - Real-time PubSub streaming across major EVM networks
  """

  alias Lux.Web3.Multichain.Aggregator
  alias Lux.Web3.Multichain.RpcManager

  @doc "Returns list of all supported EVM chain atoms."
  defdelegate supported_chains, to: RpcManager

  @doc "Retrieves network configuration and RPC endpoints for a chain."
  defdelegate get_chain_info(chain), to: RpcManager

  @doc "Retrieves canonical chain ID for a chain atom."
  defdelegate get_chain_id(chain), to: RpcManager

  @doc "Executes an RPC call with automatic failover."
  defdelegate rpc_call(chain, method, params \\ [], opts \\ []), to: RpcManager

  @doc "Reports RPC health statistics across all chains."
  defdelegate get_rpc_health, to: RpcManager, as: :get_health

  @doc "Ingests and indexes a block."
  defdelegate ingest_block(chain, block_data), to: Aggregator

  @doc "Ingests and indexes a smart contract event."
  defdelegate ingest_event(chain, event_data), to: Aggregator

  @doc "Subscribes the calling process to real-time events."
  defdelegate subscribe(topic), to: Aggregator

  @doc "Unsubscribes the calling process from a topic."
  defdelegate unsubscribe(topic), to: Aggregator

  @doc "Queries aggregated blocks with filters."
  defdelegate query_blocks(filter \\ %{}), to: Aggregator

  @doc "Queries aggregated transactions with filters."
  defdelegate query_transactions(filter \\ %{}), to: Aggregator

  @doc "Queries aggregated events with filters."
  defdelegate query_events(filter \\ %{}), to: Aggregator

  @doc "Retrieves engine metrics and index counts."
  defdelegate get_metrics, to: Aggregator
end
