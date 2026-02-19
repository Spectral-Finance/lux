defmodule Lux.Beams.Binance.FuturesTradeBeam do
  @moduledoc """
  A beam that orchestrates futures trading on Binance with risk management.

  This beam:
  1. Fetches current market data for the trading pair
  2. Checks existing futures positions and account state
  3. Validates leverage settings
  4. Places the futures order

  ## Example

      Lux.Beams.Binance.FuturesTradeBeam.run(%{
        symbol: "BTCUSDT",
        side: "BUY",
        type: "LIMIT",
        quantity: "0.001",
        price: "40000",
        time_in_force: "GTC",
        leverage: 10
      })
      {:ok, %{
        status: "success",
        market_price: "42000.00",
        order: %{...}
      }}
  """

  use Lux.Beam,
    name: "Binance Futures Trade",
    description: "Orchestrates futures trading on Binance with position management",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Trading pair (e.g., BTCUSDT)"},
        side: %{type: :string, enum: ["BUY", "SELL"]},
        type: %{type: :string, enum: [
          "LIMIT", "MARKET", "STOP", "STOP_MARKET",
          "TAKE_PROFIT", "TAKE_PROFIT_MARKET"
        ]},
        quantity: %{type: :string, description: "Order quantity"},
        price: %{type: :string, description: "Limit price"},
        time_in_force: %{type: :string, enum: ["GTC", "IOC", "FOK", "GTX"]},
        stop_price: %{type: :string, description: "Stop price"},
        leverage: %{type: :integer, description: "Desired leverage (1-125)"},
        reduce_only: %{type: :boolean, description: "Reduce-only flag"}
      },
      required: ["symbol", "side", "type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        order: %{type: :object}
      },
      required: ["status"]
    },
    generate_execution_log: true

  alias Lux.Lenses.Binance.MarketDataLens
  alias Lux.Prisms.Binance.FuturesLeveragePrism
  alias Lux.Prisms.Binance.FuturesOrderPrism

  require Logger

  sequence do
    # 1. Fetch current market price
    step(:market_data, MarketDataLens, %{
      type: "ticker_price",
      symbol: [:input, :symbol],
      endpoint: "futures"
    })

    # 2. Set leverage if provided
    step(:set_leverage, FuturesLeveragePrism, %{
      action: "set_leverage",
      symbol: [:input, :symbol],
      leverage: [:input, :leverage]
    })

    # 3. Place the futures order
    step(:place_order, FuturesOrderPrism, %{
      symbol: [:input, :symbol],
      side: [:input, :side],
      type: [:input, :type],
      quantity: [:input, :quantity],
      price: [:input, :price],
      time_in_force: [:input, :time_in_force],
      stop_price: [:input, :stop_price],
      reduce_only: [:input, :reduce_only]
    })
  end
end
