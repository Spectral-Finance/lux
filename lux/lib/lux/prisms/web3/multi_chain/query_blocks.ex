defmodule Lux.Prisms.Web3.MultiChain.QueryBlocks do
  @moduledoc """
  A Prism for querying the latest block data across all aggregated chains.
  """
  use Lux.Prism

  alias Lux.Integrations.Web3.MultiChain.Aggregator

  def handler(_params, _context) do
    blocks = Aggregator.query_latest_blocks()
    {:ok, %{status: "success", data: blocks}}
  end
end
