defmodule Lux.Prisms.Binance.PositionRiskPrism do
  @moduledoc """
  Calculates futures position liquidation price, unrealized PnL, and margin health status.
  """

  use Lux.Prism,
    name: "Binance Position Risk",
    description: "Evaluates liquidation price, ROE%, and margin ratio for Binance Futures",
    input_schema: %{
      type: :object,
      properties: %{
        side: %{type: :string, description: "BUY or SELL"},
        entry_price: %{type: :number, description: "Average entry price"},
        mark_price: %{type: :number, description: "Current mark price"},
        quantity: %{type: :number, description: "Position contract size"},
        leverage: %{type: :integer, default: 10}
      },
      required: ["side", "entry_price", "mark_price", "quantity"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        liquidation_price: %{type: :number},
        unrealized_pnl: %{type: :number},
        roe_pct: %{type: :number}
      },
      required: ["liquidation_price", "unrealized_pnl", "roe_pct"]
    }

  alias Lux.Integrations.Binance.FuturesTrading

  def handler(input, _ctx) do
    side = Map.get(input, :side) || Map.get(input, "side", "BUY")
    entry_px = (Map.get(input, :entry_price) || Map.get(input, "entry_price", 0.0)) * 1.0
    mark_px = (Map.get(input, :mark_price) || Map.get(input, "mark_price", 0.0)) * 1.0
    qty = (Map.get(input, :quantity) || Map.get(input, "quantity", 0.0)) * 1.0
    leverage = Map.get(input, :leverage) || Map.get(input, "leverage", 10)

    liq_px = FuturesTrading.calculate_liquidation_price(side, entry_px, leverage)
    pnl_data = FuturesTrading.calculate_pnl(side, entry_px, mark_px, qty, leverage)

    {:ok,
     %{
       liquidation_price: liq_px,
       unrealized_pnl: pnl_data.unrealized_pnl,
       roe_pct: pnl_data.roe_pct
     }}
  end
end
