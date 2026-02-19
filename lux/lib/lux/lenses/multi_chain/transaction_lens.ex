defmodule Lux.Lenses.MultiChain.TransactionLens do
  @moduledoc """
  Lens for fetching transaction lists and details across EVM chains.

  Provides access to normal, internal, and token transactions for an address
  via the Etherscan v2 API with chain routing.

  ## Examples

      # Get recent transactions for an address on Ethereum
      Lux.Lenses.MultiChain.TransactionLens.focus(%{
        address: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
        chainid: 1
      })

      # Get transactions on Polygon with block range
      Lux.Lenses.MultiChain.TransactionLens.focus(%{
        address: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
        chainid: 137,
        startblock: 45000000,
        endblock: 45001000
      })
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "MultiChain.TransactionLens",
    description: "Fetches transaction data across multiple EVM chains",
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
        address: %{
          type: :string,
          description: "Address to get transactions for",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        startblock: %{
          type: :integer,
          description: "Starting block number",
          default: 0
        },
        endblock: %{
          type: :integer,
          description: "Ending block number",
          default: 99_999_999
        },
        page: %{
          type: :integer,
          description: "Page number",
          default: 1
        },
        offset: %{
          type: :integer,
          description: "Number of results per page",
          default: 10
        },
        sort: %{
          type: :string,
          description: "Sort direction",
          enum: ["asc", "desc"],
          default: "desc"
        }
      },
      required: ["address"]
    }

  def before_focus(params) do
    params
    |> Map.put(:module, "account")
    |> Map.put(:action, "txlist")
  end

  @impl true
  def after_focus(response) do
    Base.process_response(response)
  end
end
