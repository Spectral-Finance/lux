defmodule Lux.Prisms.Binance.CancelOrderPrism do
  @moduledoc """
  A prism that cancels orders on the Binance exchange.

  Supports cancelling both spot and futures orders by order ID or
  all open orders for a given symbol.

  ## Examples

      # Cancel a specific spot order
      iex> Lux.Prisms.Binance.CancelOrderPrism.run(%{
      ...>   symbol: "BTCUSDT",
      ...>   order_id: 123456,
      ...>   market: "spot"
      ...> })
      {:ok, %{
        status: "success",
        cancelled_order: %{
          order_id: 123456,
          symbol: "BTCUSDT",
          status: "CANCELED"
        }
      }}

      # Cancel all open orders for a symbol
      iex> Lux.Prisms.Binance.CancelOrderPrism.run(%{
      ...>   symbol: "ETHUSDT",
      ...>   cancel_all: true,
      ...>   market: "spot"
      ...> })
      {:ok, %{status: "success", cancelled_orders: [...]}}

  The prism reads authentication details from `Lux.Config`:
  - `:binance_api_key` - Binance API key
  - `:binance_secret_key` - Binance secret key
  """

  use Lux.Prism,
    name: "Binance Cancel Order",
    description: "Cancels orders on Binance exchange (spot and futures)",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'BTCUSDT')"
        },
        order_id: %{
          type: :integer,
          description: "Order ID to cancel (not required if cancel_all is true)"
        },
        market: %{
          type: :string,
          description: "Market type: spot or futures",
          enum: ["spot", "futures"]
        },
        cancel_all: %{
          type: :boolean,
          description: "Cancel all open orders for the symbol",
          default: false
        }
      },
      required: ["symbol"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        cancelled_order: %{
          type: :object,
          properties: %{
            order_id: %{type: :integer},
            symbol: %{type: :string},
            status: %{type: :string}
          }
        },
        cancelled_orders: %{
          type: :array,
          items: %{type: :object}
        }
      },
      required: ["status"]
    }

  alias Lux.Integrations.Binance.Client

  require Logger

  @doc """
  Handles the order cancellation request.
  """
  def handler(params, ctx) do
    agent_name = get_in(ctx, [:agent, :name]) || "Unknown Agent"
    market = Map.get(params, :market, "spot")
    endpoint = if market == "futures", do: :futures, else: :spot
    plug = Map.get(params, :plug)

    if Map.get(params, :cancel_all, false) do
      cancel_all_orders(params.symbol, endpoint, agent_name, plug)
    else
      cancel_single_order(params, endpoint, agent_name, plug)
    end
  end

  defp cancel_single_order(params, endpoint, agent_name, plug) do
    order_id = Map.fetch!(params, :order_id)
    Logger.info("Agent #{agent_name} cancelling order #{order_id} for #{params.symbol}")

    path = if endpoint == :futures, do: "/fapi/v1/order", else: "/api/v3/order"

    case Client.request(:delete, path, %{symbol: params.symbol, orderId: order_id},
           signed: true, endpoint: endpoint, plug: plug) do
      {:ok, data} ->
        Logger.info("Order #{order_id} cancelled successfully")
        {:ok, %{
          status: "success",
          cancelled_order: %{
            order_id: data["orderId"],
            symbol: data["symbol"],
            status: data["status"],
            side: data["side"],
            type: data["type"],
            price: data["price"],
            orig_qty: data["origQty"]
          }
        }}

      {:error, {_status, -2011, _msg}} ->
        {:error, "Order not found or already cancelled"}

      {:error, {_status, code, msg}} ->
        {:error, "Binance API error (#{code}): #{msg}"}

      {:error, reason} ->
        {:error, "Cancel failed: #{inspect(reason)}"}
    end
  end

  defp cancel_all_orders(symbol, endpoint, agent_name, plug) do
    Logger.info("Agent #{agent_name} cancelling all orders for #{symbol}")

    path = if endpoint == :futures, do: "/fapi/v1/allOpenOrders", else: "/api/v3/openOrders"

    case Client.request(:delete, path, %{symbol: symbol},
           signed: true, endpoint: endpoint, plug: plug) do
      {:ok, data} when is_list(data) ->
        cancelled = Enum.map(data, fn o ->
          %{order_id: o["orderId"], symbol: o["symbol"], status: o["status"]}
        end)
        Logger.info("Cancelled #{length(cancelled)} orders for #{symbol}")
        {:ok, %{status: "success", cancelled_orders: cancelled}}

      {:ok, _data} ->
        {:ok, %{status: "success", cancelled_orders: []}}

      {:error, {_status, code, msg}} ->
        {:error, "Binance API error (#{code}): #{msg}"}

      {:error, reason} ->
        {:error, "Cancel all failed: #{inspect(reason)}"}
    end
  end
end
