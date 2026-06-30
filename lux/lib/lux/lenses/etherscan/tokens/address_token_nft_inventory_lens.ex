defmodule Lux.Lenses.Etherscan.AddressTokenNFTInventory do
  @moduledoc """
  Lens for fetching the ERC-721 token inventory of an address, filtered by contract address from the Etherscan API.

  Note: This endpoint is throttled to 2 calls/second regardless of API Pro tier.

  ## Examples

  ```elixir
  # Get address ERC721 token inventory (default chainid: 1 for Ethereum, page: 1, offset: 100)
  Lux.Lenses.Etherscan.AddressTokenNFTInventory.focus(%{
    address: "0x123432244443b54409430979df8333f9308a6040",
    contractaddress: "0xed5af388653567af2f388e6224dc7c4b3241c544"
  })

  # Get address ERC721 token inventory with pagination
  Lux.Lenses.Etherscan.AddressTokenNFTInventory.focus(%{
    address: "0x123432244443b54409430979df8333f9308a6040",
    contractaddress: "0xed5af388653567af2f388e6224dc7c4b3241c544",
    page: 1,
    offset: 100,
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.AddressTokenNFTInventory",
    description: "Lists all individual NFTs owned by an address from a specific NFT collection contract",
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
          description: "Wallet address to query for NFT ownership (must be valid hex format)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        contractaddress: %{
          type: :string,
          description: "NFT collection contract address to filter results by (must be valid hex format)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        page: %{
          type: :integer,
          description: "Page number for paginated results when wallet holds many NFTs in the collection",
          default: 1
        },
        offset: %{
          type: :integer,
          description: "Number of individual NFT tokens to return per page (max 100)",
          default: 100
        }
      },
      required: ["address", "contractaddress"]
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
    |> Map.put(:action, "addresstokennftinventory")
    
    # Check if this endpoint requires a Pro API key
    case Base.check_pro_endpoint("account", "addresstokennftinventory") do
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
        # Process the list of NFT tokens
        processed_results = Enum.map(result, fn nft ->
          %{
            contract_address: Map.get(nft, "TokenAddress", ""),
            name: Map.get(nft, "TokenName", ""),
            symbol: Map.get(nft, "TokenSymbol", ""),
            token_id: Map.get(nft, "TokenId", ""),
            token_uri: Map.get(nft, "TokenUri", "")
          }
        end)

        # Return a structured response
        {:ok, %{
          result: processed_results,
          nft_inventory: processed_results
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
