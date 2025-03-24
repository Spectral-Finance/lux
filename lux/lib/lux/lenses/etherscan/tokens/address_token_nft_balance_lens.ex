defmodule Lux.Lenses.Etherscan.AddressTokenNFTBalance do
  @moduledoc """
  Lens for fetching the ERC-721 tokens and amount held by an address from the Etherscan API.

  Note: This endpoint is throttled to 2 calls/second regardless of API Pro tier.

  ## Examples

  ```elixir
  # Get address ERC721 token balances (default chainid: 1 for Ethereum, page: 1, offset: 100)
  Lux.Lenses.Etherscan.AddressTokenNFTBalance.focus(%{
    address: "0x6b52e83941eb10f9c613c395a834457559a80114"
  })

  # Get address ERC721 token balances with pagination
  Lux.Lenses.Etherscan.AddressTokenNFTBalance.focus(%{
    address: "0x6b52e83941eb10f9c613c395a834457559a80114",
    page: 1,
    offset: 100,
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.AddressTokenNFTBalance",
    description: "Retrieves all ERC-721 NFT collections and quantities held by a specific wallet address",
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
          description: "Wallet address to query for NFT holdings (must be valid hex format)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        page: %{
          type: :integer,
          description: "Page number for paginated results when wallet holds many NFT collections",
          default: 1
        },
        offset: %{
          type: :integer,
          description: "Number of NFT collection records to return per page (max 100)",
          default: 100
        }
      },
      required: ["address"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Ensure page and offset parameters have default values
    params = params
    |> Map.put_new(:page, 1)
    |> Map.put_new(:offset, 100)

    # Set module and action for this endpoint
    params = params
    |> Map.put(:module, "account")
    |> Map.put(:action, "addresstokennftbalance")
    
    # Check if this endpoint requires a Pro API key
    case Base.check_pro_endpoint("account", "addresstokennftbalance") do
      {:ok, _} -> params
      {:error, message} -> raise ArgumentError, message
    end
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} when is_list(result) ->
        # Process the list of NFT balances
        processed_results = Enum.map(result, fn nft ->
          %{
            contract_address: Map.get(nft, "TokenAddress", ""),
            name: Map.get(nft, "TokenName", ""),
            symbol: Map.get(nft, "TokenSymbol", ""),
            quantity: Map.get(nft, "TokenQuantity", ""),
            token_id: Map.get(nft, "TokenId", "")
          }
        end)

        # Return a structured response
        {:ok, %{
          result: processed_results,
          nft_balances: processed_results
        }}
      {:error, %{result: "Max rate limit reached"}} ->
        # Handle rate limit error
        {:error, %{message: "Error", result: "Max rate limit reached, this endpoint is throttled to 2 calls/second"}}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end
