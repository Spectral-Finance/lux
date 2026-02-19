defmodule Lux.Lenses.MultiChain.BlockLens do
  @moduledoc """
  Lens for fetching block data across multiple EVM chains.

  Uses the Etherscan v2 unified API endpoint which supports multiple chains
  via the `chainid` parameter.

  ## Examples

      # Get latest block info from Ethereum
      Lux.Lenses.MultiChain.BlockLens.focus(%{chainid: 1})

      # Get block info from Polygon
      Lux.Lenses.MultiChain.BlockLens.focus(%{chainid: 137, blockno: 50000000})
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "MultiChain.BlockLens",
    description: "Fetches block data across multiple EVM chains via Etherscan v2 API",
    url: "https://api.etherscan.io/v2/api",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Base.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        chainid: %{
          type: :integer,
          description: "Chain ID (1=Ethereum, 137=Polygon, 56=BSC, etc.)",
          default: 1
        },
        blockno: %{
          type: :integer,
          description: "Block number to query (omit for latest)"
        },
        closest: %{
          type: :string,
          description: "Direction for timestamp-based lookup (before/after)",
          enum: ["before", "after"]
        },
        timestamp: %{
          type: :integer,
          description: "Unix timestamp for block lookup"
        }
      }
    }

  def before_focus(params) do
    if params[:timestamp] do
      params
      |> Map.put(:module, "block")
      |> Map.put(:action, "getblocknobytime")
      |> Map.put_new(:closest, "before")
    else
      params
      |> Map.put(:module, "block")
      |> Map.put(:action, "getblockreward")
      |> Map.put_new(:blockno, "latest")
    end
  end

  @impl true
  def after_focus(response) do
    Base.process_response(response)
  end
end
