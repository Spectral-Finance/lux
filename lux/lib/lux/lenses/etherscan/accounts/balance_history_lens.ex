defmodule Lux.Lenses.Etherscan.BalanceHistory do
  @moduledoc """
  Lens for fetching historical ETH balance for an Ethereum address at a specific block from the Etherscan API.

  Note: This endpoint is throttled to 2 calls/second regardless of API Pro tier.

  ## Examples

  ```elixir
  # Get historical ETH balance for an address at a specific block (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.BalanceHistory.focus(%{
    address: "0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae",
    blockno: 8_000_000
  })

  # Get historical ETH balance for an address at a specific block on a specific chain
  Lux.Lenses.Etherscan.BalanceHistory.focus(%{
    address: "0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae",
    blockno: 8_000_000,
    chainid: 1
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.BalanceHistory",
    description: "Retrieves ETH balance for an address at a specific historical block number across supported networks",
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
          description: "Target Ethereum address in standard 0x hex format",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        blockno: %{
          type: :integer,
          description: "Specific historical block height to query balance at"
        }
      },
      required: ["address", "blockno"]
    }

  @doc """
  Prepares parameters before making the API request.
  Validates that the required parameters are provided and checks if the endpoint requires a Pro API key.
  """
  def before_focus(params) do
    # Set module and action for this endpoint
    params = params
    |> Map.put(:module, "account")
    |> Map.put(:action, "balancehistory")

    # Check if this endpoint requires a Pro API key
    case Base.check_pro_endpoint("account", "balancehistory") do
      {:ok, _} -> params
      {:error, message} -> raise ArgumentError, message
    end
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    Base.process_response(response)
  end
end
