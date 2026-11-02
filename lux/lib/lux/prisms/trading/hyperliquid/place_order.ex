defmodule Lux.Prisms.Trading.Hyperliquid.PlaceOrderPrism do
  @moduledoc """
  Validates, prices, and submits perpetual orders to Hyperliquid with risk checks.
  """

  use Lux.Prism,
    name: "Place Hyperliquid Order",
    description: "Validates and submits perpetual limit, market, and stop orders to Hyperliquid",
    input_schema: %{
      type: :object,
      properties: %{
        coin: %{type: :string, description: "Trading asset symbol (e.g. BTC, ETH, SOL)"},
        is_buy: %{type: :boolean, description: "True for Buy/Long, False for Sell/Short", default: true},
        sz: %{type: :number, description: "Order size in base currency"},
        limit_px: %{type: :number, description: "Limit price (optional for market orders)"},
        order_type: %{type: :string, enum: ["limit", "market", "stop_loss", "take_profit", "trailing_stop"], default: "limit"},
        tif: %{type: :string, enum: ["gtc", "ioc", "alo"], default: "gtc"},
        trigger_px: %{type: :number, description: "Trigger price for stop loss or take profit orders"},
        reduce_only: %{type: :boolean, default: false}
      },
      required: ["coin", "sz"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        order_id: %{type: :string},
        coin: %{type: :string},
        is_buy: %{type: :boolean},
        sz: %{type: :number},
        limit_px: %{type: :number},
        status: %{type: :string}
      },
      required: ["order_id", "coin", "is_buy", "sz", "status"]
    }

  alias Lux.Trading.Hyperliquid.OrderManager

  def handler(input, _ctx) do
    case OrderManager.build_order(input) do
      {:ok, order} ->
        {:ok,
         %{
           order_id: order.id,
           coin: order.coin,
           is_buy: order.is_buy,
           sz: order.sz,
           limit_px: order.limit_px,
           status: to_string(order.status)
         }}

      {:error, reason} ->
        {:error, "Order building failed: #{inspect(reason)}"}
    end
  end
end
