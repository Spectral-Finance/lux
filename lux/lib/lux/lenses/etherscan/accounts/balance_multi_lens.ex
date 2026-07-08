defmodule Lux.Lenses.Etherscan.BalanceMulti do
  @moduledoc """
  Lens for fetching ETH balances for multiple Ethereum addresses from the Etherscan API.

  ## Examples

  ```elixir
  # Get ETH balances for multiple addresses (default chainid: 1 for Ethereum)
  Lux.Lenses.Etherscan.BalanceMulti.focus(%{
    addresses: ["0x742d35Cc6634C0532925a3b844Bc454e4438f44e", "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"]
  })

  # Get ETH balances for multiple addresses on a specific chain (e.g., 137 for Polygon)
  Lux.Lenses.Etherscan.BalanceMulti.focus(%{
    addresses: ["0x742d35Cc6634C0532925a3b844Bc454e4438f44e", "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"],
    chainid: 137
  })
  ```
  """

  alias Lux.Lenses.Etherscan.Base

  use Lux.Lens,
    name: "Etherscan.BalanceMulti",
    description: "Retrieves current ETH balances for up to 20 addresses in a single request",
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
        addresses: %{
          type: :array,
          description: "Array of Ethereum addresses to query balances for (maximum 20)",
          items: %{
            type: :string,
            pattern: "^0x[a-fA-F0-9]{40}$"
          },
          maxItems: 20
        },
        tag: %{
          type: :string,
          description: "Block reference point for balance query (latest, pending, or earliest)",
          enum: ["latest", "pending", "earliest"],
          default: "latest"
        }
      },
      required: ["addresses"]
    }

  @doc """
  Prepares parameters before making the API request.
  """
  def before_focus(params) do
    # Convert addresses array to comma-separated string
    address_string = Enum.join(params.addresses, ",")

    # Set module and action for this endpoint
    params
    |> Map.delete(:addresses)  # Remove the addresses list to avoid URI encoding issues
    |> Map.put(:module, "account")
    |> Map.put(:action, "balancemulti")
    |> Map.put(:address, address_string)
  end

  @doc """
  Transforms the API response into a more usable format.
  """
  @impl true
  def after_focus(response) do
    Base.process_response(response)
  end
end
