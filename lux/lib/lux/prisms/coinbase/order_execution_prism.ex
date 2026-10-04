defmodule Lux.Prisms.Coinbase.OrderExecutionPrism do
  @moduledoc """
  Prism for placing and managing orders on Coinbase Advanced Trade with pre-trade risk validation.
  """
  use Lux.Prism,
    name: "Coinbase Order Execution Prism",
    description: "Evaluates risk limits and safely executes orders on Coinbase Advanced Trade",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{
          type: :string,
          description: "Trading product identifier (e.g. BTC-USD, ETH-USD)"
        },
        side: %{
          type: :string,
          enum: ["BUY", "SELL"],
          description: "Order side"
        },
        order_type: %{
          type: :string,
          enum: ["MARKET", "LIMIT", "STOP_LIMIT"],
          description: "Order execution type"
        },
        size: %{
          type: :number,
          description: "Base asset size to buy/sell"
        },
        price: %{
          type: :number,
          description: "Limit price"
        },
        client_order_id: %{
          type: :string,
          description: "Optional client idempotency ID"
        },
        skip_risk_check: %{
          type: :boolean,
          description: "Whether to bypass local risk checks (default false)"
        }
      },
      required: ["product_id", "side", "order_type"]
    }

  require Logger
  import Lux.Python

  @impl true
  def handler(input, _ctx) do
    product_id = Map.get(input, "product_id") || Map.get(input, :product_id)
    side = Map.get(input, "side") || Map.get(input, :side)
    order_type = Map.get(input, "order_type") || Map.get(input, :order_type)
    size = Map.get(input, "size") || Map.get(input, :size)
    price = Map.get(input, "price") || Map.get(input, :price)
    client_order_id = Map.get(input, "client_order_id") || Map.get(input, :client_order_id)
    skip_risk_check = Map.get(input, "skip_risk_check", false)

    python_result =
      python variables: %{
               product_id: product_id,
               side: side,
               order_type: order_type,
               size: size,
               price: price,
               client_order_id: client_order_id,
               skip_risk_check: skip_risk_check
             } do
        ~PY"""
        from lux.coinbase.pipeline import CoinbasePipeline
        from lux.coinbase.types import OrderPlacementRequest

        pipeline = CoinbasePipeline()
        req = OrderPlacementRequest(
            product_id=product_id,
            side=side,
            order_type=order_type,
            size=size,
            price=price,
            client_order_id=client_order_id,
        )
        result = pipeline.execute_order(req, skip_risk_check=skip_risk_check)
        result
        """
      end

    case python_result do
      %{"status" => "REJECTED_BY_RISK_LIMITS"} = rej ->
        {:error, "Order rejected by risk limits: #{rej["reason"]}"}

      %{"status" => "FAILED"} = fail ->
        {:error, "Order execution failed: #{fail["reason"]}"}

      %{"status" => "SUBMITTED"} = success ->
        {:ok, success}

      %{"error" => err} ->
        {:error, err}

      other when is_map(other) ->
        {:ok, other}

      other ->
        {:error, "Unexpected order execution result: #{inspect(other)}"}
    end
  end
end
