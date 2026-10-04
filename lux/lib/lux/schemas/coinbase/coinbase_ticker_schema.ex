defmodule Lux.Schemas.Coinbase.TickerSchema do
  @moduledoc """
  Schema definition for Coinbase Advanced Trade real-time ticker data.
  """
  use Lux.SignalSchema,
    name: "Coinbase Ticker Schema",
    description: "Schema for Coinbase Advanced Trade ticker pricing and 24h stats",
    schema: %{
      type: :object,
      properties: %{
        product_id: %{
          type: :string,
          description: "Trading pair identifier (e.g. BTC-USD, ETH-USD)"
        },
        price: %{
          type: :number,
          description: "Current mid or last traded price"
        },
        best_bid: %{
          type: :number,
          description: "Current highest buy order price"
        },
        best_ask: %{
          type: :number,
          description: "Current lowest sell order price"
        },
        volume_24h: %{
          type: :number,
          description: "24-hour total trading volume in base currency"
        },
        high_24h: %{
          type: :number,
          description: "Highest price observed over the past 24 hours"
        },
        low_24h: %{
          type: :number,
          description: "Lowest price observed over the past 24 hours"
        },
        timestamp: %{
          type: :string,
          description: "ISO-8601 or epoch timestamp of the price snapshot"
        }
      },
      required: ["product_id", "price"]
    }
end
