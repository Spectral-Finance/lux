defmodule Lux.Prisms.Coinbase.CreateOrderPrism do
  @moduledoc """
  A prism for creating orders on the Coinbase Advanced Trade API.

  Supports market, limit (GTC, GTD, FOK, IOC), and stop-limit order types.

  ## Examples

      iex> Lux.Prisms.Coinbase.CreateOrderPrism.handler(%{
      ...>   product_id: "BTC-USD",
      ...>   side: "BUY",
      ...>   order_type: "limit",
      ...>   base_size: "0.001",
      ...>   limit_price: "60000.00"
      ...> }, %{name: "Agent"})
      {:ok, %{
        order_id: "abc123",
        product_id: "BTC-USD",
        side: "BUY",
        status: "PENDING",
        created_time: "2024-01-01T00:00:00Z"
      }}
  """

  use Lux.Prism,
    name: "Coinbase Create Order",
    description: "Creates a new order on Coinbase Advanced Trade",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{type: :string, description: "Trading pair (e.g., 'BTC-USD')"},
        side: %{type: :string, description: "Order side", enum: ["BUY", "SELL"]},
        order_type: %{
          type: :string,
          description: "Order configuration type",
          enum: ["market", "limit_limit_gtc", "limit_limit_gtd", "limit_limit_fok", "limit_limit_ioc", "stop_limit_stop_limit_gtc"]
        },
        base_size: %{type: :string, description: "Order size in base currency"},
        quote_size: %{type: :string, description: "Order size in quote currency (for market orders)"},
        limit_price: %{type: :string, description: "Limit price (for limit orders)"},
        stop_price: %{type: :string, description: "Stop trigger price (for stop-limit orders)"},
        end_time: %{type: :string, description: "Order expiry time ISO8601 (for GTD orders)"},
        post_only: %{type: :boolean, description: "If true, order will be post-only", default: false}
      },
      required: ["product_id", "side", "order_type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        order_id: %{type: :string},
        product_id: %{type: :string},
        side: %{type: :string},
        status: %{type: :string},
        created_time: %{type: :string}
      },
      required: ["order_id", "product_id", "status"]
    }

  alias Lux.Integrations.Coinbase
  require Logger

  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} creating #{params.side} #{params.order_type} order for #{params.product_id}")

    body = build_order_body(params)

    case Coinbase.post("/api/v3/brokerage/orders", body) do
      {:ok, %{"success" => true, "order_id" => order_id, "success_response" => resp}} ->
        result = %{
          order_id: order_id,
          product_id: resp["product_id"] || params.product_id,
          side: resp["side"] || params.side,
          status: resp["status"] || "PENDING",
          created_time: resp["created_time"]
        }
        Logger.info("Coinbase order created: #{order_id}")
        {:ok, result}

      {:ok, %{"success" => false, "error_response" => %{"error" => err, "message" => msg}}} ->
        Logger.error("Coinbase order failed: #{err} - #{msg}")
        {:error, {422, msg}}

      {:error, {status, body}} ->
        msg = get_in(body, ["message"]) || inspect(body)
        Logger.error("Coinbase create order error: #{status} - #{msg}")
        {:error, {status, msg}}

      {:error, reason} ->
        Logger.error("Coinbase order request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_order_body(params) do
    order_config = build_order_config(params)

    %{
      product_id: params.product_id,
      side: params.side,
      order_configuration: order_config
    }
  end

  defp build_order_config(%{order_type: "market", base_size: base_size}),
    do: %{market_market_ioc: %{base_size: base_size}}

  defp build_order_config(%{order_type: "market", quote_size: quote_size}),
    do: %{market_market_ioc: %{quote_size: quote_size}}

  defp build_order_config(%{order_type: "limit_limit_gtc"} = params),
    do: %{limit_limit_gtc: %{base_size: params.base_size, limit_price: params.limit_price, post_only: Map.get(params, :post_only, false)}}

  defp build_order_config(%{order_type: "limit_limit_gtd"} = params),
    do: %{limit_limit_gtd: %{base_size: params.base_size, limit_price: params.limit_price, end_time: params.end_time, post_only: Map.get(params, :post_only, false)}}

  defp build_order_config(%{order_type: "limit_limit_fok"} = params),
    do: %{sor_limit_ioc: %{base_size: params.base_size, limit_price: params.limit_price}}

  defp build_order_config(%{order_type: "stop_limit_stop_limit_gtc"} = params),
    do: %{stop_limit_stop_limit_gtc: %{base_size: params.base_size, limit_price: params.limit_price, stop_price: params.stop_price}}

  defp build_order_config(%{order_type: type}),
    do: %{type => %{}}
end
