defmodule Lux.Prisms.Binance.SpotOrderPrism do
  @moduledoc """
  A prism that places spot orders on the Binance exchange.

  Supports all spot order types: LIMIT, MARKET, STOP_LOSS_LIMIT,
  TAKE_PROFIT_LIMIT, LIMIT_MAKER, and more.

  ## Examples

      # Market buy order
      iex> Lux.Prisms.Binance.SpotOrderPrism.run(%{
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
          executed_qty: "0.001",
          fills: [...]
        }
      }}

      # Limit sell order
      iex> Lux.Prisms.Binance.SpotOrderPrism.run(%{
      ...>   symbol: "BTCUSDT",
      ...>   side: "SELL",
      ...>   type: "LIMIT",
      ...>   quantity: "0.001",
      ...>   price: "50000",
      ...>   time_in_force: "GTC"
      ...> })
      {:ok, %{status: "success", order: %{...}}}

  The prism reads authentication details from `Lux.Config`:
  - `:binance_api_key` - Binance API key
  - `:binance_secret_key` - Binance secret key
  """

  use Lux.Prism,
    name: "Binance Spot Order",
    description: "Places spot orders on Binance exchange",
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
          enum: ["LIMIT", "MARKET", "STOP_LOSS_LIMIT", "TAKE_PROFIT_LIMIT", "LIMIT_MAKER"]
        },
        quantity: %{
          type: :string,
          description: "Order quantity in base asset"
        },
        price: %{
          type: :string,
          description: "Order price (required for LIMIT orders)"
        },
        time_in_force: %{
          type: :string,
          description: "Time in force (GTC, IOC, FOK)",
          enum: ["GTC", "IOC", "FOK"]
        },
        stop_price: %{
          type: :string,
          description: "Stop price (for STOP_LOSS_LIMIT and TAKE_PROFIT_LIMIT)"
        },
        quote_order_qty: %{
          type: :string,
          description: "Quote asset quantity (for MARKET orders as alternative to quantity)"
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
            time_in_force: %{type: :string},
            fills: %{type: :array}
          }
        }
      },
      required: ["status", "order"]
    }

  alias Lux.Integrations.Binance.Client

  require Logger

  @doc """
  Handles the spot order placement request.
  """
  def handler(params, ctx) do
    agent_name = get_in(ctx, [:agent, :name]) || "Unknown Agent"
    Logger.info("Agent #{agent_name} placing spot order: #{params.symbol} #{params.side} #{params.type}")

    order_params = build_order_params(params)
    plug = Map.get(params, :plug)

    case Client.request(:post, "/api/v3/order", order_params, signed: true, endpoint: :spot, plug: plug) do
      {:ok, data} ->
        order = format_order(data)
        Logger.info("Spot order placed: #{inspect(order.order_id)} #{order.status}")
        {:ok, %{status: "success", order: order}}

      {:error, {:rate_limited, _}} ->
        {:error, "Rate limited by Binance API. Please try again later."}

      {:error, {_status, -2010, msg}} ->
        {:error, "Insufficient balance: #{msg}"}

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
    |> maybe_add(:quoteOrderQty, params[:quote_order_qty])
    |> maybe_add(:newOrderRespType, "FULL")
  end

  defp maybe_add(params, _key, nil), do: params
  defp maybe_add(params, key, value), do: Map.put(params, key, value)

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
      time_in_force: data["timeInForce"],
      transact_time: data["transactTime"],
      fills: data["fills"] || []
    }
  end
end
