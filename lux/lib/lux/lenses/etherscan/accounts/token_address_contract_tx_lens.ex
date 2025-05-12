defmodule Lux.Lenses.Etherscan.TokenAddressContractTx do
  @moduledoc """
  Lens for fetching ERC-20 token transfer events for a specific address filtered by a token contract from the Etherscan API.

  ## Examples

  ```elixir
  # Get ERC-20 transfers for an address filtered by a token contract
  Lux.Lenses.Etherscan.TokenAddressContractTx.focus(%{
    address: "0x4e83362442b8d1bec281594cea3050c8eb01311c",
    contractaddress: "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2"
  })

  # With additional parameters
  Lux.Lenses.Etherscan.TokenAddressContractTx.focus(%{
    address: "0x4e83362442b8d1bec281594cea3050c8eb01311c",
    contractaddress: "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
    chainid: 1,
    startblock: 0,
    endblock: 27_025_780,
    page: 1,
    offset: 100,
    sort: "asc"
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.TokenAddressContractTx",
    description: "Retrieves ERC-20 token transfers for a specific wallet address from a specific token contract",
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
          description: "Network identifier (1=Ethereum, 137=Polygon, 56=BSC, etc.)",
          default: 1
        },
        address: %{
          type: :string,
          description: "Wallet address to query for token transfers (must be valid hex format)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        contractaddress: %{
          type: :string,
          description: "Token contract address to filter transfers by (must be valid hex format)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        startblock: %{
          type: :integer,
          description: "Starting block number to filter transfer events from",
          default: 0
        },
        endblock: %{
          type: :integer,
          description: "Ending block number to filter transfer events to",
          default: 99_999_999
        },
        page: %{
          type: :integer,
          description: "Page number for paginated results when many transfers exist",
          default: 1
        },
        offset: %{
          type: :integer,
          description: "Number of transfer records to return per page (max 10_000)",
          default: 100
        },
        sort: %{
          type: :string,
          description: "Chronological ordering of results (asc=oldest first, desc=newest first)",
          enum: ["asc", "desc"],
          default: "asc"
        }
      },
      required: ["address", "contractaddress"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Set module and action for this endpoint
    params
    |> Map.put(:module, "account")
    |> Map.put(:action, "tokentx")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    Base.process_response(response)
  end
end 