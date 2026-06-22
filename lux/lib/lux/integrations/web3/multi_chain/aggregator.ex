defmodule Lux.Integrations.Web3.MultiChain.Aggregator do
  @moduledoc """
  Multi-Chain Data Aggregation Engine.
  Supervises network monitors and the centralized storage.
  """
  use Supervisor

  alias Lux.Integrations.Web3.MultiChain.Storage
  alias Lux.Integrations.Web3.MultiChain.NetworkMonitor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    children = [
      Storage
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Dynamically adds a new chain to monitor.
  """
  def add_chain(chain_id, rpc_url) do
    child_spec = %{
      id: :"chain_monitor_#{chain_id}",
      start: {NetworkMonitor, :start_link, [%{chain_id: chain_id, rpc_url: rpc_url}]}
    }

    Supervisor.start_child(__MODULE__, child_spec)
  end

  @doc """
  Queries aggregated events across all currently tracked chains.
  """
  def query_events(chain_id \\ nil) do
    Storage.get_events(chain_id)
  end

  @doc """
  Queries the latest known block for all chains.
  """
  def query_latest_blocks() do
    Storage.get_latest_blocks()
  end
end
