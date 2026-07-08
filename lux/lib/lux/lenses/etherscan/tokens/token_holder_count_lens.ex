defmodule Lux.Lenses.Etherscan.TokenHolderCount do
  @moduledoc """
  Lens for fetching a simple count of the number of ERC20 token holders from the Etherscan API.

  ## Examples

  ```elixir
  # Get token holder count (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.TokenHolderCount.focus(%{
    contractaddress: "0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d"
  })

  # Get token holder count on a specific chain
  Lux.Lenses.Etherscan.TokenHolderCount.focus(%{
    contractaddress: "0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d",
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.TokenHolderCount",
    description: "Returns the total number of unique addresses holding a specific ERC-20 token",
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
          description: "ERC-20 token contract address to query holder count for (must be valid hex format)",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["contractaddress"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Set module and action for this endpoint
    params = params
    |> Map.put(:module, "token")
    |> Map.put(:action, "tokenholdercount")
    
    # Check if this endpoint requires a Pro API key
    case Base.check_pro_endpoint("token", "tokenholdercount") do
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
        # Return a structured response with the token holder count
        {:ok, %{
          result: result,
          holder_count: result
        }}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end
