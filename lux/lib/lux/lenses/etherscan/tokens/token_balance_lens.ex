defmodule Lux.Lenses.Etherscan.TokenBalance do
  @moduledoc """
  Lens for fetching the current balance of an ERC-20 token of an address from the Etherscan API.

  ## Examples

  ```elixir
  # Get ERC20 token balance for an address (default chainid: 1 for Ethereum, tag: "latest")
  Lux.Lenses.Etherscan.TokenBalance.focus(%{
    contractaddress: "0x57d90b64a1a57749b0f932f1a3395792e12e7055",
    address: "0xe04f27eb70e025b78871a2ad7eabe85e61212761"
  })

  # Get ERC20 token balance for an address on a specific chain
  Lux.Lenses.Etherscan.TokenBalance.focus(%{
    contractaddress: "0x57d90b64a1a57749b0f932f1a3395792e12e7055",
    address: "0xe04f27eb70e025b78871a2ad7eabe85e61212761",
    tag: "latest",
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.TokenBalance",
    description: "Retrieves current ERC-20 token balance for a specific wallet address",
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
        tag: %{
          type: :string,
          description: "Block parameter to query (latest=current state, pending=mempool state, earliest=genesis block)",
          enum: ["latest", "pending", "earliest"],
          default: "latest"
        }
      },
      required: ["contractaddress", "address"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Ensure tag parameter has a default value
    params = case params[:tag] do
      nil -> Map.put(params, :tag, "latest")
      _ -> params
    end

    # Set module and action for this endpoint
    params
    |> Map.put(:module, "account")
    |> Map.put(:action, "tokenbalance")
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    case Base.process_response(response) do
      {:ok, %{result: result}} ->
        # Return a structured response with the token balance
        {:ok, %{
          result: result,
          token_balance: result
        }}
      other ->
        # Pass through other responses (like errors)
        other
    end
  end
end
