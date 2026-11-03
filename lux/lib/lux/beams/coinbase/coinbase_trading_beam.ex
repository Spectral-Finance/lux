defmodule Lux.Beams.Coinbase.CoinbaseTradingBeam do
  @moduledoc """
  A coordinated workflow beam for executing Coinbase Advanced Trade orders:
  1. Inspects Level 2 orderbook depth and spread
  2. Estimates execution fees based on maker/taker tiers
  3. Prepares validated order payload with unique client order ID
  """

  use Lux.Beam,
    name: "Coinbase Trading Execution Beam",
    description: "Evaluates orderbook spread, calculates fees, and prepares validated Coinbase Advanced Trade orders",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{type: :string, description: "Market symbol (e.g. BTC-USD)"},
        side: %{type: :string, description: "BUY or SELL"},
        base_size: %{type: :number, description: "Quantity of base currency to trade"},
        limit_price: %{type: :number, description: "Limit price"},
        fee_type: %{type: :string, default: "taker"},
        bids: %{type: :array, default: []},
        asks: %{type: :array, default: []}
      },
      required: ["product_id", "side", "base_size", "limit_price"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        market_metrics: %{type: :object},
        fee_metrics: %{type: :object},
        order_details: %{type: :object}
      },
      required: ["status"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Coinbase.OrderbookPrism
  alias Lux.Prisms.Coinbase.FeeEstimatePrism
  alias Lux.Prisms.Coinbase.OrderPrism

  sequence do
    step(:market_depth, OrderbookPrism, %{
      product_id: [:input, :product_id],
      bids: [:input, :bids],
      asks: [:input, :asks]
    })

    step(:fee_estimation, FeeEstimatePrism, %{
      quantity: [:input, :base_size],
      price: [:input, :limit_price],
      fee_type: [:input, :fee_type]
    })

    step(:order, OrderPrism, %{
      product_id: [:input, :product_id],
      side: [:input, :side],
      type: "LIMIT",
      base_size: [:input, :base_size],
      limit_price: [:input, :limit_price]
    })
  end
end
