defmodule Lux.Prisms.Web3.MultiChain.AddChain do
  @moduledoc """
  A Prism for adding a new chain to the Multi-Chain Aggregator.
  """
  use Lux.Prism

  alias Lux.Integrations.Web3.MultiChain.Aggregator

  def handler(params, _context) do
    chain_id = Map.fetch!(params, :chain_id)
    rpc_url = Map.fetch!(params, :rpc_url)

    case Aggregator.add_chain(chain_id, rpc_url) do
      {:ok, _pid} -> {:ok, %{status: "success", message: "Started monitoring chain #{chain_id}"}}
      {:error, {:already_started, _pid}} -> {:ok, %{status: "already_running", message: "Chain #{chain_id} is already being monitored"}}
      error -> {:error, "Failed to start monitor: #{inspect(error)}"}
    end
  end
end
