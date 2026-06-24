defmodule Lux.Lenses.Hyperliquid.Trading.CreateOrder do
  @moduledoc """
  A lens that creates a perpetual trading order on Hyperliquid.

  Delegates to `Lux.Prisms.Hyperliquid.HyperliquidExecuteOrderPrism` for execution.

  ## Examples

      iex> CreateOrder.focus(%{coin: "ETH", is_buy: true, sz: 0.1, limit_px: 2800.0, order_type: %{limit: %{tif: "Gtc"}}})
      {:ok, %{status: "success", order_result: %{...}}}
  """

  use Lux.Lens,
    name: "Hyperliquid Create Order",
    description: "Creates a perpetual trading order on Hyperliquid",
    schema: %{
      type: :object,
      properties: %{
        coin: %{type: :string, description: "Trading pair symbol (e.g. ETH, BTC)"},
        is_buy: %{type: :boolean, description: "True for buy, false for sell"},
        sz: %{type: :number, description: "Order size in base currency"},
        limit_px: %{type: :number, description: "Limit price"},
        order_type: %{
          type: :object,
          description: "Order type (limit or trigger)",
          oneOf: [
            %{
              type: :object,
              properties: %{
                limit: %{
                  type: :object,
                  properties: %{
                    tif: %{type: :string, enum: ["Alo", "Ioc", "Gtc"]}
                  },
                  required: ["tif"]
                }
              },
              required: ["limit"]
            },
            %{
              type: :object,
              properties: %{
                trigger: %{
                  type: :object,
                  properties: %{
                    triggerPx: %{type: :number},
                    isMarket: %{type: :boolean},
                    tpsl: %{type: :string, enum: ["tp", "sl"]}
                  },
                  required: ["triggerPx", "isMarket", "tpsl"]
                }
              },
              required: ["trigger"]
            }
          ]
        },
        reduce_only: %{type: :boolean, default: false},
        vault_address: %{type: :string, pattern: "^0x[a-fA-F0-9]{40}$"}
      },
      required: ["coin", "is_buy", "sz", "limit_px", "order_type"]
    }

  def focus(params) do
    Lux.Prisms.Hyperliquid.HyperliquidExecuteOrderPrism.run(params)
  end
end
