defmodule Lux.Prisms.Binance.FuturesOrderPrism do
  @moduledoc """
  A prism that places futures orders on the Binance exchange.

  Supports USDT-margined futures order types: LIMIT, MARKET, STOP,
  STOP_MARKET, TAKE_PROFIT, TAKE_PROFIT_MARKET, and TRAILING_STOP_MARKET.

  ## Examples

      # Market order
      iex> Lux.Prisms.Binance.FuturesOrderPrism.run(%{
      ...>   symbol: "BTCUSDT",
      ...>   side: "BUY",
      ...>   type: "MARKET",
      ...>   quantity: "0.001"
      ...> })
      {:ok, %{
        status: "success",
        order: %{
          order_id: 123456,
          symbol: "BTCUSDT",
          side: "BUY",
          type: "MARKET",
          status: "FILLED",
          ...
        }
      }}

      # Limit order with reduce-only
      iex> Lux.Prisms.Binance.FuturesOrderPrism.run(%{
      ...>   symbol: "ETHUSDT",
      ...>   side: "SELL",
      ...>   type: "LIMIT",
      ...>   quantity: "0.1",
      ...>   price: "3000",
      ...>   time_in_force: "GTC",
      ...>   reduce_only: true
      ...> })
      {:ok, %{status: "success", order: %{...}}}

      # Stop-loss market order
      iex> Lux.Prisms.Binance.FuturesOrderPrism.run(%{
      ...>   symbol: "BTCUSDT",
      ...>   side: "SELL",
      ...>   type: "STOP_MARKET",
      ...>   quantity: "0.001",
      ...>   stop_price: "38000",
      ...>   reduce_only: true
      ...> })
      {:ok, %{status: "success", order: %{...}}}

  The prism reads authentication details from `Lux.Config`:
  - `:binance_api_key` - Binance API key
  - `:binance_secret_key` - Binance secret key
  """

  use Lux.Prism,
    name: "Binance Futures Order",
    description: "Places futures orders on Binance exchange",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'BTCUSDT')"
        },
        side: %{
          type: :string,
          description: "Order side",
          enum: ["BUY", "SELL"]
        },
        type: %{
          type: :string,
          description: "Order type",
          enum: [
            "LIMIT", "MARKET", "STOP", "STOP_MARKET",
            "TAKE_PROFIT", "TAKE_PROFIT_MARKET", "TRAILING_STOP_MARKET"
          ]
        },
        quantity: %{
          type: :string,
          description: "Order quantity"
        },
        price: %{
          type: :string,
          description: "Order price (required for LIMIT orders)"
        },
        time_in_force: %{
          type: :string,
          description: "Time in force (GTC, IOC, FOK, GTX)",
          enum: ["GTC", "IOC", "FOK", "GTX"]
        },
        stop_price: %{
          type: :string,
          description: "Stop price (for stop/take-profit orders)"
        },
        reduce_only: %{
          type: :boolean,
          description: "Whether the order should only reduce a position",
          default: false
        },
        position_side: %{
          type: :string,
          description: "Position side for hedge mode (BOTH, LONG, SHORT)",
          enum: ["BOTH", "LONG", "SHORT"]
        },
        callback_rate: %{
          type: :string,
          description: "Callback rate for TRAILING_STOP_MARKET (1-5%)"
        }
      },
      required: ["symbol", "side", "type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        order: %{
          type: :object,
          properties: %{
            order_id: %{type: :integer},
            symbol: %{type: :string},
            side: %{type: :string},
            type: %{type: :string},
            status: %{type: :string},
            price: %{type: :string},
            orig_qty: %{type: :string},
            executed_qty: %{type: :string},
            position_side: %{type: :string},
            reduce_only: %{type: :boolean}
          }
        }
      },
      required: ["status", "order"]
    }

  alias Lux.Integrations.Binance.Client

  require Logger

  @doc """
  Handles the futures order placement request.
  """
  def handler(params, ctx) do
    agent_name = get_in(ctx, [:agent, :name]) || "Unknown Agent"
    Logger.info("Agent #{agent_name} placing futures order: #{params.symbol} #{params.side} #{params.type}")

    order_params = build_order_params(params)
    plug = Map.get(params, :plug)

    case Client.request(:post, "/fapi/v1/order", order_params, signed: true, endpoint: :futures, plug: plug) do
      {:ok, data} ->
        order = format_order(data)
        Logger.info("Futures order placed: #{inspect(order.order_id)} #{order.status}")
        {:ok, %{status: "success", order: order}}

      {:error, {:rate_limited, _}} ->
        {:error, "Rate limited by Binance API. Please try again later."}

      {:error, {_status, -2019, msg}} ->
        {:error, "Insufficient margin: #{msg}"}

      {:error, {_status, -4003, msg}} ->
        {:error, "Quantity too small: #{msg}"}

      {:error, {_status, -1121, msg}} ->
        {:error, "Invalid symbol: #{msg}"}

      {:error, {_status, code, msg}} ->
        {:error, "Binance API error (#{code}): #{msg}"}

      {:error, reason} ->
        {:error, "Order failed: #{inspect(reason)}"}
    end
  end

  defp build_order_params(params) do
    base = %{
      symbol: params.symbol,
      side: params.side,
      type: params.type
    }

    base
    |> maybe_add(:quantity, params[:quantity])
    |> maybe_add(:price, params[:price])
    |> maybe_add(:timeInForce, params[:time_in_force])
    |> maybe_add(:stopPrice, params[:stop_price])
    |> maybe_add(:reduceOnly, to_string_bool(params[:reduce_only]))
    |> maybe_add(:positionSide, params[:position_side])
    |> maybe_add(:callbackRate, params[:callback_rate])
    |> maybe_add(:newOrderRespType, "RESULT")
  end

  defp maybe_add(params, _key, nil), do: params
  defp maybe_add(params, _key, "nil"), do: params
  defp maybe_add(params, key, value), do: Map.put(params, key, value)

  defp to_string_bool(true), do: "true"
  defp to_string_bool(false), do: "false"
  defp to_string_bool(nil), do: nil

  defp format_order(data) do
    %{
      order_id: data["orderId"],
      symbol: data["symbol"],
      side: data["side"],
      type: data["type"],
      status: data["status"],
      price: data["price"],
      orig_qty: data["origQty"],
      executed_qty: data["executedQty"],
      avg_price: data["avgPrice"],
      position_side: data["positionSide"],
      reduce_only: data["reduceOnly"],
      time_in_force: data["timeInForce"],
      update_time: data["updateTime"]
    }
  end
end
