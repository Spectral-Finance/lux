defmodule Lux.Lenses.Coinbase.OrderLens do
  @moduledoc """
  Lens for loading order details, open orders, and fee schedules from Coinbase Advanced Trade.
  """
  use Lux.Lens,
    name: "Coinbase Order Lens",
    description: "Queries open orders, order history, and fee rates on Coinbase Advanced Trade",
    schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["get_order", "list_orders", "get_transaction_summary"],
          description: "Order query action"
        },
        order_id: %{
          type: :string,
          description: "Unique order identifier"
        },
        product_id: %{
          type: :string,
          description: "Filter orders by product identifier"
        },
        order_status: %{
          type: :string,
          description: "Filter orders by lifecycle status (e.g. OPEN, FILLED)"
        },
        limit: %{
          type: :integer,
          description: "Maximum orders to return"
        }
      },
      required: ["action"]
    }

  require Logger
  import Lux.Python

  @impl true
  def focus(params) do
    action = Map.get(params, "action") || Map.get(params, :action) || "list_orders"
    order_id = Map.get(params, "order_id") || Map.get(params, :order_id)
    product_id = Map.get(params, "product_id") || Map.get(params, :product_id)
    order_status = Map.get(params, "order_status") || Map.get(params, :order_status)
    limit = Map.get(params, "limit") || Map.get(params, :limit) || 50

    python_result =
      python variables: %{
               action: action,
               order_id: order_id,
               product_id: product_id,
               order_status: order_status,
               limit: limit
             } do
        ~PY"""
        from lux.coinbase.rest import CoinbaseRestClient

        client = CoinbaseRestClient()
        res = {}

        if action == "get_order":
            order = client.get_order(order_id)
            res = {"status": "ok", "order": order.model_dump()}
        elif action == "list_orders":
            orders = client.list_orders(product_id=product_id, order_status=order_status, limit=limit)
            res = {"status": "ok", "orders": [o.model_dump() for o in orders]}
        elif action == "get_transaction_summary":
            summary = client.get_transaction_summary()
            res = {"status": "ok", "transaction_summary": summary}
        else:
            res = {"status": "error", "message": f"Unsupported action {action}"}

        res
        """
      end

    after_focus(python_result)
  end

  @doc """
  Transforms the response into a structured Elixir map.
  """
  def after_focus(%{"status" => "ok"} = result) do
    {:ok, result}
  end

  def after_focus(%{"status" => "error", "message" => msg}) do
    {:error, msg}
  end

  def after_focus(%{"error" => err}) do
    {:error, err}
  end

  def after_focus(other) when is_map(other) do
    {:ok, other}
  end

  def after_focus(err) do
    {:error, "Unexpected order response: #{inspect(err)}"}
  end
end
