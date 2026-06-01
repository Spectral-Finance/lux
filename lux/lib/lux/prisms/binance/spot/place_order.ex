defmodule Lux.Prisms.Binance.Spot.PlaceOrder do
  @moduledoc """
  A prism for placing spot orders on Binance.

  Supports MARKET and LIMIT order types on the spot market.
  Requires API key and secret key with trading permissions.

  ## Examples

      iex> PlaceOrder.handler(%{
      ...>   symbol: "BTCUSDT",
      ...>   side: "BUY",
      ...>   type: "MARKET",
      ...>   quantity: "0.001"
      ...> }, %{name: "TradingAgent"})
      {:ok, %{
        order_id: 12345,
        symbol: "BTCUSDT",
        status: "FILLED",
        side: "BUY",
        type: "MARKET",
        executed_qty: "0.001"
      }}
  """

  use Lux.Prism,
    name: "Binance Place Spot Order",
    description: "Places a spot order (MARKET or LIMIT) on Binance",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Trading pair, e.g. BTCUSDT"},
        side: %{type: :string, description: "BUY or SELL", enum: ["BUY", "SELL"]},
        type: %{
          type: :string,
          description: "Order type: MARKET, LIMIT, STOP_LOSS_LIMIT, etc.",
          enum: ["MARKET", "LIMIT", "STOP_LOSS_LIMIT", "TAKE_PROFIT_LIMIT"]
        },
        quantity: %{type: :string, description: "Order quantity in base asset"},
        price: %{type: :string, description: "Order price (required for LIMIT orders)"},
        time_in_force: %{
          type: :string,
          description: "GTC, IOC, or FOK (required for LIMIT orders)",
          enum: ["GTC", "IOC", "FOK"]
        },
        api_key: %{type: :string, description: "Binance API key (uses config if omitted)"},
        secret_key: %{type: :string, description: "Binance secret key (uses config if omitted)"}
      },
      required: ["symbol", "side", "type", "quantity"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        order_id: %{type: :integer, description: "Binance order ID"},
        symbol: %{type: :string, description: "Trading pair"},
        status: %{type: :string, description: "Order status"},
        side: %{type: :string, description: "BUY or SELL"},
        type: %{type: :string, description: "Order type"},
        executed_qty: %{type: :string, description: "Amount executed so far"}
      },
      required: ["order_id", "symbol", "status"]
    }

  alias Lux.Integrations.Binance.Client
  require Logger

  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown"

    with {:ok, symbol} <- fetch(params, :symbol),
         {:ok, side} <- fetch(params, :side),
         {:ok, type} <- fetch(params, :type),
         {:ok, quantity} <- fetch(params, :quantity) do

      Logger.info("Agent #{agent_name} placing #{side} #{type} order for #{quantity} #{symbol}")

      order_params = %{
        symbol: symbol,
        side: side,
        type: type,
        quantity: quantity
      }
      |> maybe_put(:price, params[:price])
      |> maybe_put(:timeInForce, params[:time_in_force])

      case Client.request(:post, "/api/v3/order", %{
        signed: true,
        api_key: params[:api_key],
        secret_key: params[:secret_key],
        params: order_params
      }) do
        {:ok, resp} ->
          {:ok, %{
            order_id: resp["orderId"],
            symbol: resp["symbol"],
            status: resp["status"],
            side: resp["side"],
            type: resp["type"],
            executed_qty: resp["executedQty"],
            transact_time: resp["transactTime"]
          }}

        {:error, {:bad_request, code, msg}} ->
          {:error, "Order rejected (#{code}): #{msg}"}

        {:error, {:unauthorized, _code, msg}} ->
          {:error, "Unauthorized: #{msg}"}

        {:error, :rate_limited} ->
          {:error, "Rate limited — retry after cooling down"}

        {:error, err} ->
          {:error, "Failed to place order: #{inspect(err)}"}
      end
    end
  end

  defp fetch(params, key) do
    case Map.fetch(params, key) do
      {:ok, val} when is_binary(val) and val != "" -> {:ok, val}
      _ -> {:error, "Missing required parameter: #{key}"}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)
end
