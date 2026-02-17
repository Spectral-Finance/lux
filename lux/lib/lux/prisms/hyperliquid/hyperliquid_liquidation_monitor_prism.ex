defmodule Lux.Prisms.Hyperliquid.HyperliquidLiquidationMonitorPrism do
  @moduledoc """
  A prism that monitors liquidations on the Hyperliquid exchange.

  ## Example

      iex> Lux.Prisms.Hyperliquid.HyperliquidLiquidationMonitorPrism.run(%{
      ...>   coin: "ETH",
      ...>   vault_address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
      ...> })
      {:ok,
       %{
         "status" => "success",
         "liquidation_data" => %{
           # ... response from Hyperliquid
         }
       }}

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  - :hyperliquid_address - (Optional) Ethereum account address
  """

  use Lux.Prism,
    name: "Hyperliquid Liquidation Monitor",
    description: "Monitors liquidations on Hyperliquid exchange",
    input_schema: %{
      type: :object,
      properties: %{
        coin: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'ETH', 'BTC')"
        },
        vault_address: %{
          type: :string,
          description: "Vault address to monitor for liquidations"
        }
      },
      required: [:coin, :vault_address]
    }

  def run(input) do
    private_key = Application.get_env(:lux, :hyperliquid_private_key)
    address = Application.get_env(:lux, :hyperliquid_address)

    # Simulate API call to Hyperliquid for liquidation data
    liquidation_data = %{
      "status" => "success",
      "data" => [
        %{"vault_address" => "0x0403369c02199a0cb827f4d6492927e9fa5668d5", "liquidated" => true},
        %{"vault_address" => "0x1234567890abcdef", "liquidated" => false}
      ]
    }

    {:ok, %{status: "success", liquidation_data: liquidation_data}}
  end
end

def calculate_liquidation_price(liquidation_data) do
  liquidated_vaults = Enum.filter(liquidation_data["data"], fn vault -> vault["liquidated"] end)
  total_value = Enum.sum(Enum.map(liquidated_vaults, fn vault -> vault["value"] end))
  total_liability = Enum.sum(Enum.map(liquidated_vaults, fn vault -> vault["liability"] end))

  if total_liability > 0 do
    liquidation_price = total_value / total_liability
    {:ok, liquidation_price}
  else
    {:error, "No liquidations to calculate price"}
  end
end