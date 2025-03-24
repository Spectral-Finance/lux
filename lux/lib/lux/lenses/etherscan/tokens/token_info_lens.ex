defmodule Lux.Lenses.Etherscan.TokenInfo do
  @moduledoc """
  Lens for fetching project information and social media links of an ERC20/ERC721/ERC1155 token from the Etherscan API.

  Note: This endpoint is throttled to 2 calls/second regardless of API Pro tier.

  ## Examples

  ```elixir
  # Get token info (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.TokenInfo.focus(%{
    contractaddress: "0x0e3a2a1f2146d86a604adc220b4967a898d7fe07"
  })

  # Get token info on a specific chain
  Lux.Lenses.Etherscan.TokenInfo.focus(%{
    contractaddress: "0x0e3a2a1f2146d86a604adc220b4967a898d7fe07",
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.TokenInfo",
    description: "Retrieves comprehensive token metadata including project details, social media links, and current price",
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
          description: "Token contract address to query metadata for (works with ERC-20, ERC-721, or ERC-1155)",
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
    |> Map.put(:action, "tokeninfo")

    # Check if this endpoint requires a Pro API key
    case Base.check_pro_endpoint("token", "tokeninfo") do
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
        # Process the token info
        processed_results = Enum.map(result, fn token ->
          %{
            contract_address: Map.get(token, "contractAddress", ""),
            token_name: Map.get(token, "tokenName", ""),
            symbol: Map.get(token, "symbol", ""),
            divisor: Map.get(token, "divisor", ""),
            token_type: Map.get(token, "tokenType", ""),
            total_supply: Map.get(token, "totalSupply", ""),
            blue_check_mark: Map.get(token, "blueCheckmark", ""),
            description: Map.get(token, "description", ""),
            website: Map.get(token, "website", ""),
            email: Map.get(token, "email", ""),
            blog: Map.get(token, "blog", ""),
            reddit: Map.get(token, "reddit", ""),
            slack: Map.get(token, "slack", ""),
            facebook: Map.get(token, "facebook", ""),
            twitter: Map.get(token, "twitter", ""),
            github: Map.get(token, "github", ""),
            telegram: Map.get(token, "telegram", ""),
            wechat: Map.get(token, "wechat", ""),
            linkedin: Map.get(token, "linkedin", ""),
            discord: Map.get(token, "discord", ""),
            whitepaper: Map.get(token, "whitepaper", ""),
            token_price_usd: Map.get(token, "tokenPriceUSD", "")
          }
        end)

        # Return a structured response
        {:ok, %{
          result: processed_results,
          token_info: processed_results
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
