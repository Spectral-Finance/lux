defmodule Lux.Schemas.TradeProposalSchema do
  @moduledoc false
  use Lux.SignalSchema,
    name: "trade_proposal",
    version: "1.0.0",
    description: "Represents a proposed trade from market research",
    schema: %{
      type: :object,
      properties: %{
        coin: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'ETH', 'BTC')"
        },
        is_buy: %{
          type: :boolean,
          description: "True for buy orders, false for sell orders"
        },
        sz: %{
          type: :number,
          description: "Position size in base currency units"
        },
        limit_px: %{
          type: :number,
          description: "Limit price for the order"
        },
        order_type: %{
          type: :object,
          properties: %{
            limit: %{
              type: :object,
              properties: %{
                tif: %{
                  type: :string,
                  enum: ["Gtc"],
                  description: "Time in force - Good till cancelled"
                }
              },
              required: ["tif"]
            }
          },
          required: ["limit"]
        },
        reduce_only: %{
          type: :boolean,
          description: "Whether this order can only reduce position size"
        },
        rationale: %{
          type: :string,
          description: "Detailed explanation of the trade recommendation"
        }
      },
      required: [
        "coin",
        "is_buy",
        "sz",
        "limit_px",
        "order_type",
        "reduce_only",
        "rationale"
      ]
    }
end
