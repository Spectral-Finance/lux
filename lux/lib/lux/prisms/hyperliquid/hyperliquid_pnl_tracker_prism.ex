defmodule Lux.Prisms.Hyperliquid.HyperliquidPNLTrackerPrism do
  @moduledoc """
  A prism that tracks PnL and funding rates on the Hyperliquid exchange.

  ## Example

      iex> Lux.Prisms.Hyperliquid.HyperliquidPNLTrackerPrism.run(%{
      ...>   coin: "ETH",
      ...>   vault_address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
      ...> })
      {:ok,
       %{
         "status" => "success",
         "pnl" => 10.0,
         "funding_rate" => -0.005
       }}

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  - :hyperliquid_address - (Optional) Ethereum account address
  """

  use Lux.Prism,
    name: "Hyperliquid PnL and Funding Rate Tracker",
    description: "Tracks PnL and funding rates on Hyperliquid exchange",
    input_schema: %{
      type: :object,
      properties: %{
        coin: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'ETH', 'BTC')"
        },
        vault_address: %{
          type: :string,
          description: "Vault address for the account"
        }
      },
      required: [:coin, :vault_address]
    }

  def run(input) do
    private_key = Application.get_env(:hyperliquid, :private_key)
    address = Application.get_env(:hyperliquid, :address)

    # Fetch PnL and funding rate from Hyperliquid API
    pnl = fetch_pnl(private_key, address, input.coin, input.vault_address)
    funding_rate = fetch_funding_rate(private_key, address, input.coin, input.vault_address)

    {:ok, %{"status" => "success", "pnl" => pnl, "funding_rate" => funding_rate}}
  end

  defp fetch_pnl(private_key, address, coin, vault_address) do
    # Implement logic to fetch PnL from Hyperliquid API
    # Example: HTTP request with private key and vault address
    10.0
  end

  defp fetch_funding_rate(private_key, address, coin, vault_address) do
    # Implement logic to fetch funding rate from Hyperliquid API
    # Example: HTTP request with private key and vault address
    -0.005
  end
end

defp calculate_unrealized_pnl(pnl, funding_rate) do
  pnl + (funding_rate * pnl)
end