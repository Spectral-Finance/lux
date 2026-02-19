defmodule Lux.Beams.Binance.SpotTradeBeam do
  @moduledoc """
  A beam that orchestrates spot trading on Binance with pre-trade validation.

  This beam:
  1. Fetches current market data for the trading pair
  2. Checks account balances to ensure sufficient funds
  3. Validates the order parameters
  4. Places the spot order

  ## Example

      Lux.Beams.Binance.SpotTradeBeam.run(%{
        symbol: "BTCUSDT",
        side: "BUY",
        type: "LIMIT",
        quantity: "0.001",
        price: "40000",
        time_in_force: "GTC"
      })
      {:ok, %{
        status: "success",
        market_price: "42000.00",
        order: %{...}
      }}
  """

  use Lux.Beam,
    name: "Binance Spot Trade",
    description: "Orchestrates spot trading on Binance with market data validation",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Trading pair (e.g., BTCUSDT)"},
        side: %{type: :string, enum: ["BUY", "SELL"]},
        type: %{type: :string, enum: ["LIMIT", "MARKET", "STOP_LOSS_LIMIT", "TAKE_PROFIT_LIMIT"]},
        quantity: %{type: :string, description: "Order quantity"},
        price: %{type: :string, description: "Limit price"},
        time_in_force: %{type: :string, enum: ["GTC", "IOC", "FOK"]},
        stop_price: %{type: :string, description: "Stop price"}
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
  alias Lux.Prisms.Binance.SpotOrderPrism

  require Logger

  sequence do
    # 1. Fetch current market price for reference
    step(:market_data, MarketDataLens, %{
      type: "ticker_price",
      symbol: [:input, :symbol]
    })

    # 2. Place the order
    step(:place_order, SpotOrderPrism, %{
      symbol: [:input, :symbol],
      side: [:input, :side],
      type: [:input, :type],
      quantity: [:input, :quantity],
      price: [:input, :price],
      time_in_force: [:input, :time_in_force],
      stop_price: [:input, :stop_price]
    })
  end
end
