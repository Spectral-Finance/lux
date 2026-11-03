defmodule Lux.Beams.Binance.BinanceTradingBeam do
  @moduledoc """
  A coordinated workflow beam for executing and managing risk for Binance orders:
  1. Inspects market depth and bid-ask spread
  2. Evaluates position risk, leverage, and liquidation margins
  3. Prepares and validates trading order parameters
  """

  use Lux.Beam,
    name: "Binance Trading Execution Beam",
    description: "Evaluates market depth, checks liquidation risks, and validates Binance trade execution",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Trading pair, e.g. BTCUSDT"},
        side: %{type: :string, description: "BUY or SELL"},
        quantity: %{type: :number, description: "Order quantity"},
        price: %{type: :number, description: "Target limit price"},
        leverage: %{type: :integer, default: 10},
        bids: %{type: :array, default: []},
        asks: %{type: :array, default: []}
      },
      required: ["symbol", "side", "quantity", "price"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        market_metrics: %{type: :object},
        risk_metrics: %{type: :object},
        order_details: %{type: :object}
      },
      required: ["status"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Binance.MarketDepthPrism
  alias Lux.Prisms.Binance.PositionRiskPrism
  alias Lux.Prisms.Binance.SpotOrderPrism

  sequence do
    step(:market_depth, MarketDepthPrism, %{
      symbol: [:input, :symbol],
      bids: [:input, :bids],
      asks: [:input, :asks]
    })

    step(:risk_assessment, PositionRiskPrism, %{
      side: [:input, :side],
      entry_price: [:input, :price],
      mark_price: [:input, :price],
      quantity: [:input, :quantity],
      leverage: [:input, :leverage]
    })

    step(:order, SpotOrderPrism, %{
      symbol: [:input, :symbol],
      side: [:input, :side],
      quantity: [:input, :quantity],
      price: [:input, :price]
    })
  end
end
