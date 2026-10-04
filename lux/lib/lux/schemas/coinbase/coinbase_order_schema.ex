defmodule Lux.Schemas.Coinbase.OrderSchema do
  @moduledoc """
  Schema definition for Coinbase Advanced Trade orders.
  """
  use Lux.SignalSchema,
    name: "Coinbase Order Schema",
    description: "Schema for Coinbase Advanced Trade order placement, lifecycle updates, and execution status",
    schema: %{
      type: :object,
      properties: %{
        order_id: %{
          type: :string,
          description: "Unique server order identifier"
        },
        client_order_id: %{
          type: :string,
          description: "Client-supplied idempotency identifier"
        },
        product_id: %{
          type: :string,
          description: "Trading product identifier (e.g. BTC-USD)"
        },
        side: %{
          type: :string,
          enum: ["BUY", "SELL"],
          description: "Order side"
        },
        order_type: %{
          type: :string,
          enum: ["MARKET", "LIMIT", "STOP_LIMIT", "STOP"],
          description: "Order execution strategy type"
        },
        price: %{
          type: :number,
          description: "Order limit price"
        },
        size: %{
          type: :number,
          description: "Order size in base currency"
        },
        status: %{
          type: :string,
          enum: ["OPEN", "FILLED", "CANCELLED", "EXPIRED", "FAILED", "PENDING"],
          description: "Current lifecycle status"
        },
        filled_size: %{
          type: :number,
          description: "Amount of base currency filled so far"
        },
        filled_value: %{
          type: :number,
          description: "Total fiat/quote value executed"
        },
        fee: %{
          type: :number,
          description: "Transaction fee charged"
        },
        created_at: %{
          type: :string,
          description: "Order creation timestamp"
        }
      },
      required: ["order_id", "product_id", "side", "status"]
    }
end
