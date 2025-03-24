defmodule Lux.Lenses.Etherscan.AddressTokenBalance do
  @moduledoc """
  Lens for fetching the ERC-20 tokens and amount held by an address from the Etherscan API.

  Note: This endpoint is throttled to 2 calls/second regardless of API Pro tier.

  ## Examples

  ```elixir
  # Get address token balances (default chainid: 1 for Ethereum, page: 1, offset: 100)
  Lux.Lenses.Etherscan.AddressTokenBalance.focus(%{
    address: "0x983e3660c0bE01991785F80f266A84B911ab59b0"
  })

  # Get address token balances with pagination
  Lux.Lenses.Etherscan.AddressTokenBalance.focus(%{
    address: "0x983e3660c0bE01991785F80f266A84B911ab59b0",
    page: 1,
    offset: 100,
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.AddressTokenBalance",
    description: "Retrieves all ERC-20 tokens and quantities held by a specific wallet address",
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
          description: "Wallet address to query for token balances (must be valid hex format)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        page: %{
          type: :integer,
          description: "Page number for paginated results when wallet holds many tokens",
          default: 1
        },
        offset: %{
          type: :integer,
          description: "Number of token records to return per page (max 100)",
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
    |> Map.put(:action, "addresstokenbalance")
    
    # Check if this endpoint requires a Pro API key
    case Base.check_pro_endpoint("account", "addresstokenbalance") do
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
        # Process the list of token balances
        processed_results = Enum.map(result, fn token ->
          %{
            token_address: Map.get(token, "TokenAddress", ""),
            token_name: Map.get(token, "TokenName", ""),
            token_symbol: Map.get(token, "TokenSymbol", ""),
            token_decimals: Map.get(token, "TokenDec", ""),
            token_quantity: Map.get(token, "TokenQuantity", "")
          }
        end)

        # Return a structured response
        {:ok, %{
          result: processed_results,
          token_balances: processed_results
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
