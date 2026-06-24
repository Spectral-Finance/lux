defmodule Lux.Prisms.Binance.PlaceOrderPrism do
  @moduledoc """
  A prism for placing orders on the Binance exchange.

  Supports spot and futures markets with LIMIT, MARKET, STOP_LOSS_LIMIT,
  and TAKE_PROFIT_LIMIT order types.

  ## Examples

      iex> Lux.Prisms.Binance.PlaceOrderPrism.handler(%{
      ...>   symbol: "BTCUSDT",
      ...>   side: "BUY",
      ...>   type: "LIMIT",
      ...>   quantity: "0.001",
      ...>   price: "60000.00",
      ...>   time_in_force: "GTC"
      ...> }, %{name: "Agent"})
      {:ok, %{
        order_id: 123456789,
        client_order_id: "...",
        symbol: "BTCUSDT",
        side: "BUY",
        type: "LIMIT",
        status: "NEW",
        quantity: "0.001",
        price: "60000.00"
      }}
  """

  use Lux.Prism,
    name: "Binance Place Order",
    description: "Places a new order on the Binance exchange (spot or futures)",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'BTCUSDT')",
          pattern: "^[A-Z0-9]{2,20}$"
        },
        side: %{
          type: :string,
          description: "Order side",
          enum: ["BUY", "SELL"]
        },
        type: %{
          type: :string,
          description: "Order type",
          enum: ["LIMIT", "MARKET", "STOP_LOSS_LIMIT", "TAKE_PROFIT_LIMIT"]
        },
        quantity: %{
          type: :string,
          description: "Order quantity in base asset"
        },
        price: %{
          type: :string,
          description: "Order price (required for LIMIT orders)"
        },
        stop_price: %{
          type: :string,
          description: "Stop price (required for STOP_LOSS_LIMIT and TAKE_PROFIT_LIMIT)"
        },
        time_in_force: %{
          type: :string,
          description: "Time in force: GTC (Good Till Cancel), IOC (Immediate or Cancel), FOK (Fill or Kill)",
          enum: ["GTC", "IOC", "FOK"],
          default: "GTC"
        },
        futures: %{
          type: :boolean,
          description: "If true, place order on Futures market",
          default: false
        }
      },
      required: ["symbol", "side", "type", "quantity"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        order_id: %{type: :integer, description: "Binance order ID"},
        client_order_id: %{type: :string, description: "Client order ID"},
        symbol: %{type: :string, description: "Trading pair symbol"},
        side: %{type: :string, description: "Order side (BUY/SELL)"},
        type: %{type: :string, description: "Order type"},
        status: %{type: :string, description: "Order status"},
        quantity: %{type: :string, description: "Ordered quantity"},
        price: %{type: :string, description: "Order price"}
      },
      required: ["order_id", "symbol", "side", "status"]
    }

  alias Lux.Integrations.Binance
  require Logger

  @doc """
  Handles the request to place an order on Binance.
  """
  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    futures = Map.get(params, :futures, false)

    Logger.info("Agent #{agent_name} placing #{params.side} #{params.type} order for #{params.symbol}")

    path = if futures, do: "/fapi/v1/order", else: "/api/v3/order"

    order_params = build_order_params(params)

    case Binance.post(path, order_params, futures: futures) do
      {:ok, %{"orderId" => order_id, "symbol" => symbol, "status" => status} = data} ->
        result = %{
          order_id: order_id,
          client_order_id: data["clientOrderId"],
          symbol: symbol,
          side: data["side"],
          type: data["type"],
          status: status,
          quantity: data["origQty"],
          price: data["price"]
        }
        Logger.info("Order placed successfully: #{order_id} for #{symbol} - #{status}")
        {:ok, result}

      {:error, {status, %{"msg" => msg}}} ->
        Logger.error("Binance order error: #{status} - #{msg}")
        {:error, {status, msg}}

      {:error, reason} ->
        Logger.error("Binance order request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_order_params(params) do
    base = %{
      symbol: params.symbol,
      side: params.side,
      type: params.type,
      quantity: params.quantity
    }

    base
    |> maybe_add(params, :price, "price")
    |> maybe_add(params, :stop_price, "stopPrice")
    |> maybe_add_tif(params)
  end

  defp maybe_add(acc, params, key, binance_key) do
    case Map.get(params, key) do
      nil -> acc
      value -> Map.put(acc, binance_key, value)
    end
  end

  defp maybe_add_tif(acc) when is_map(acc) do
    # LIMIT orders require timeInForce
    if acc[:type] == "LIMIT" do
      Map.put_new(acc, :timeInForce, "GTC")
    else
      acc
    end
  end

  defp maybe_add_tif(acc, params) do
    case {acc[:type], Map.get(params, :time_in_force)} do
      {"LIMIT", nil} -> Map.put(acc, :timeInForce, "GTC")
      {"LIMIT", tif} -> Map.put(acc, :timeInForce, tif)
      {"STOP_LOSS_LIMIT", tif} -> Map.put(acc, :timeInForce, tif || "GTC")
      {"TAKE_PROFIT_LIMIT", tif} -> Map.put(acc, :timeInForce, tif || "GTC")
      _ -> acc
    end
  end
end
