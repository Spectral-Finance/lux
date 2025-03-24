defmodule Lux.Lenses.Etherscan.TokenBalanceHistory do
  @moduledoc """
  Lens for fetching the balance of an ERC-20 token of an address at a certain block height from the Etherscan API.

  Note: This endpoint is throttled to 2 calls/second regardless of API Pro tier.

  ## Examples

  ```elixir
  # Get historical ERC20 token balance for an address (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.TokenBalanceHistory.focus(%{
    contractaddress: "0x57d90b64a1a57749b0f932f1a3395792e12e7055",
    address: "0xe04f27eb70e025b78871a2ad7eabe85e61212761",
    blockno: 8_000_000
  })

  # Get historical ERC20 token balance for an address on a specific chain
  Lux.Lenses.Etherscan.TokenBalanceHistory.focus(%{
    contractaddress: "0x57d90b64a1a57749b0f932f1a3395792e12e7055",
    address: "0xe04f27eb70e025b78871a2ad7eabe85e61212761",
    blockno: 8_000_000,
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.TokenBalanceHistory",
    description: "Retrieves historical ERC-20 token balance for an address at a specific block height",
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
        contractaddress: %{
          type: :string,
          description: "ERC-20 token contract address to query (must be valid hex format)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        address: %{
          type: :string,
          description: "Wallet address to check token balance for (must be valid hex format)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        blockno: %{
          type: :integer,
          description: "Specific blockchain block number to query the token balance at"
        }
      },
      required: ["contractaddress", "address", "blockno"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Set module and action for this endpoint
    params = params
    |> Map.put(:module, "account")
    |> Map.put(:action, "tokenbalancehistory")
    
    # Check if this endpoint requires a Pro API key
    case Base.check_pro_endpoint("account", "tokenbalancehistory") do
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
      {:ok, %{result: result}} ->
        # Return a structured response with the historical token balance
        {:ok, %{
          result: result,
          token_balance: result,
          block_number: Map.get(response, "blockNumber", nil)
        }}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end
