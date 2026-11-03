defmodule Lux.Prisms.Coinbase.FeeEstimatePrism do
  @moduledoc """
  Calculates estimated trading fees for a Coinbase Advanced Trade transaction.
  """

  use Lux.Prism,
    name: "Coinbase Fee Estimate Prism",
    description: "Calculates expected taker or maker fee and net trade cost in USD",
    input_schema: %{
      type: :object,
      properties: %{
        quantity: %{type: :number, description: "Trade base amount"},
        price: %{type: :number, description: "Trade execution price"},
        fee_type: %{type: :string, default: "taker"},
        maker_fee_bps: %{type: :number, default: 40.0},
        taker_fee_bps: %{type: :number, default: 60.0}
      },
      required: ["quantity", "price"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        notional_usd: %{type: :number},
        fee_rate_bps: %{type: :number},
        estimated_fee_usd: %{type: :number},
        net_notional_usd: %{type: :number}
      },
      required: ["notional_usd", "estimated_fee_usd", "net_notional_usd"]
    }

  alias Lux.Integrations.Coinbase.AccountManager

  def handler(input, _ctx) do
    qty = (Map.get(input, :quantity) || Map.get(input, "quantity", 0.0)) * 1.0
    price = (Map.get(input, :price) || Map.get(input, "price", 0.0)) * 1.0
    type_str = Map.get(input, :fee_type) || Map.get(input, "fee_type", "taker")
    fee_type = if String.downcase(type_str) == "maker", do: :maker, else: :taker
    maker_bps = (Map.get(input, :maker_fee_bps) || Map.get(input, "maker_fee_bps", 40.0)) * 1.0
    taker_bps = (Map.get(input, :taker_fee_bps) || Map.get(input, "taker_fee_bps", 60.0)) * 1.0

    result = AccountManager.estimate_trade_fee(qty, price, fee_type, maker_bps, taker_bps)
    {:ok, result}
  end
end
