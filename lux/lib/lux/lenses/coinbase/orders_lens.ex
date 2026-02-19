defmodule Lux.Lenses.Coinbase.OrdersLens do
  @moduledoc """
  A lens for fetching historical orders from Coinbase.

  Returns a list of orders with filtering options for status,
  product, and time range.

  ## Examples

      # Get all open orders
      iex> Lux.Lenses.Coinbase.OrdersLens.focus(%{order_status: "OPEN"})
      {:ok, %{orders: [
        %{
          order_id: "abc-123",
          product_id: "BTC-USD",
          side: "BUY",
          status: "OPEN",
          order_type: "LIMIT"
        }
      ]}}

      # Get orders for a specific product
      iex> Lux.Lenses.Coinbase.OrdersLens.focus(%{product_id: "ETH-USD"})
      {:ok, %{orders: [...]}}
  """

  alias Lux.Integrations.Coinbase

  use Lux.Lens,
    name: "Coinbase Orders",
    description: "Fetches order history from Coinbase Advanced Trade API",
    url: "https://api.coinbase.com/api/v3/brokerage/orders/historical/batch",
    method: :get,
    headers: Coinbase.headers(),
    auth: Coinbase.auth(),
    schema: %{
      type: :object,
      properties: %{
        product_id: %{
          type: :string,
          description: "Filter by product ID (e.g., BTC-USD)"
        },
        order_status: %{
          type: :string,
          description: "Filter by order status",
          enum: ["OPEN", "FILLED", "CANCELLED", "EXPIRED", "FAILED", "PENDING"]
        },
        limit: %{
          type: :integer,
          description: "Maximum number of orders to return"
        },
        start_date: %{
          type: :string,
          description: "Start date filter (ISO 8601)"
        },
        end_date: %{
          type: :string,
          description: "End date filter (ISO 8601)"
        },
        order_type: %{
          type: :string,
          description: "Filter by order type",
          enum: ["MARKET", "LIMIT", "STOP", "STOP_LIMIT"]
        },
        order_side: %{
          type: :string,
          description: "Filter by order side",
          enum: ["BUY", "SELL"]
        },
        cursor: %{
          type: :string,
          description: "Pagination cursor"
        },
        product_type: %{
          type: :string,
          description: "Filter by product type",
          enum: ["SPOT", "FUTURE"]
        },
        order_placement_source: %{
          type: :string,
          description: "Filter by order placement source"
        }
      }
    }

  def after_focus(%{"orders" => orders} = response) do
    formatted =
      Enum.map(orders, fn order ->
        %{
          order_id: order["order_id"],
          product_id: order["product_id"],
          side: order["side"],
          status: order["status"],
          order_type: order["order_type"],
          created_time: order["created_time"],
          completion_percentage: order["completion_percentage"],
          filled_size: order["filled_size"],
          average_filled_price: order["average_filled_price"],
          total_fees: order["total_fees"],
          total_value_after_fees: order["total_value_after_fees"],
          order_configuration: order["order_configuration"],
          settled: order["settled"]
        }
      end)

    result = %{orders: formatted}

    result =
      if response["cursor"], do: Map.put(result, :cursor, response["cursor"]), else: result

    result =
      if response["has_next"],
        do: Map.put(result, :has_next, response["has_next"]),
        else: result

    {:ok, result}
  end

  def after_focus(%{"error" => error}), do: {:error, error}
  def after_focus(other), do: {:ok, other}
end
