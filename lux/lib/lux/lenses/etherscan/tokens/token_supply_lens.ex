defmodule Lux.Lenses.Etherscan.TokenSupply do
  @moduledoc """
  Lens for fetching the current amount of an ERC-20 token in circulation from the Etherscan API.

  ## Examples

  ```elixir
  # Get ERC20 token total supply (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.TokenSupply.focus(%{
    contractaddress: "0x57d90b64a1a57749b0f932f1a3395792e12e7055"
  })

  # Get ERC20 token total supply on a specific chain
  Lux.Lenses.Etherscan.TokenSupply.focus(%{
    contractaddress: "0x57d90b64a1a57749b0f932f1a3395792e12e7055",
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.TokenSupply",
    description: "Retrieves current total circulating supply of a specific ERC-20 token",
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
          description: "ERC-20 token contract address to query current supply for (must be valid hex format)",
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
    |> Map.put(:module, "stats")
    |> Map.put(:action, "tokensupply")

    # Check if this endpoint requires a Pro API key
    case Base.check_pro_endpoint("stats", "tokensupply") do
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
        # Return a structured response with the token supply
        {:ok, %{
          result: result,
          token_supply: result
        }}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end
