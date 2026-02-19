defmodule Lux.Lenses.Coinbase.FeesLens do
  @moduledoc """
  A lens for fetching transaction fee summary from Coinbase.

  Returns the current fee tier, volume, and fee rates for the user.

  ## Examples

      iex> Lux.Lenses.Coinbase.FeesLens.focus()
      {:ok, %{
        total_volume: 50000.0,
        total_fees: 125.0,
        fee_tier: %{
          pricing_tier: "Advanced",
          maker_fee_rate: "0.004",
          taker_fee_rate: "0.006"
        }
      }}
  """

  alias Lux.Integrations.Coinbase

  use Lux.Lens,
    name: "Coinbase Transaction Summary",
    description: "Fetches fee and transaction summary from Coinbase Advanced Trade API",
    url: "https://api.coinbase.com/api/v3/brokerage/transaction_summary",
    method: :get,
    headers: Coinbase.headers(),
    auth: Coinbase.auth(),
    schema: %{
      type: :object,
      properties: %{
        product_type: %{
          type: :string,
          description: "Filter by product type (e.g., SPOT)"
        }
      }
    }

  def after_focus(%{"total_volume" => total_volume} = response) do
    {:ok, %{
      total_volume: total_volume,
      total_fees: response["total_fees"],
      fee_tier: response["fee_tier"],
      margin_rate: response["margin_rate"],
      goods_and_services_tax: response["goods_and_services_tax"],
      advanced_trade_only_volume: response["advanced_trade_only_volume"],
      advanced_trade_only_fees: response["advanced_trade_only_fees"],
      coinbase_pro_volume: response["coinbase_pro_volume"],
      coinbase_pro_fees: response["coinbase_pro_fees"]
    }}
  end

  def after_focus(%{"error" => error}), do: {:error, error}
  def after_focus(other), do: {:ok, other}
end
