defmodule Lux.Prisms.Coinbase.OrderbookPrism do
  @moduledoc """
  Evaluates Coinbase Level 2 orderbook spread, top bids, and top asks.
  """

  use Lux.Prism,
    name: "Coinbase Orderbook Prism",
    description: "Evaluates best bid, ask, mid-market price, and spread metrics",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{type: :string, description: "Market symbol (e.g. BTC-USD)"},
        bids: %{type: :array, description: "List of orderbook bids"},
        asks: %{type: :array, description: "List of orderbook asks"}
      },
      required: ["product_id", "bids", "asks"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        product_id: %{type: :string},
        best_bid: %{type: :number},
        best_ask: %{type: :number},
        mid_market: %{type: :number},
        spread_usd: %{type: :number},
        spread_bps: %{type: :number}
      },
      required: ["product_id", "best_bid", "best_ask", "mid_market", "spread_usd", "spread_bps"]
    }

  alias Lux.Integrations.Coinbase.MarketData

  def handler(input, _ctx) do
    product_id = Map.get(input, :product_id) || Map.get(input, "product_id", "BTC-USD")
    bids = Map.get(input, :bids) || Map.get(input, "bids", [])
    asks = Map.get(input, :asks) || Map.get(input, "asks", [])

    metrics = MarketData.evaluate_orderbook(bids, asks)

    {:ok, Map.put(metrics, :product_id, String.upcase(product_id))}
  end
end
