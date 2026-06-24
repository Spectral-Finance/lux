defmodule Lux.Prisms.Binance.GetOpenOrdersPrism do
  @moduledoc """
  A prism for retrieving open (unfilled) orders from Binance.

  ## Examples

      iex> Lux.Prisms.Binance.GetOpenOrdersPrism.handler(%{symbol: "BTCUSDT"}, %{name: "Agent"})
      {:ok, %{
        orders: [%{
          order_id: 123456789,
          symbol: "BTCUSDT",
          side: "BUY",
          type: "LIMIT",
          price: "60000.00",
          quantity: "0.001",
          executed_quantity: "0.0",
          status: "NEW"
        }]
      }}
  """

  use Lux.Prism,
    name: "Binance Get Open Orders",
    description: "Retrieves all open orders for a symbol on Binance",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol (optional; if omitted returns all symbols)"
        },
        futures: %{
          type: :boolean,
          description: "If true, query Futures market",
          default: false
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        orders: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              order_id: %{type: :integer},
              symbol: %{type: :string},
              side: %{type: :string},
              type: %{type: :string},
              price: %{type: :string},
              quantity: %{type: :string},
              executed_quantity: %{type: :string},
              status: %{type: :string}
            }
          }
        }
      },
      required: ["orders"]
    }

  alias Lux.Integrations.Binance
  require Logger

  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    futures = Map.get(params, :futures, false)
    Logger.info("Agent #{agent_name} fetching open orders")

    path = if futures, do: "/fapi/v1/openOrders", else: "/api/v3/openOrders"

    query_params = case Map.get(params, :symbol) do
      nil -> %{}
      symbol -> %{symbol: symbol}
    end

    case Binance.get(path, query_params, futures: futures, signed: true) do
      {:ok, raw_orders} when is_list(raw_orders) ->
        orders = Enum.map(raw_orders, fn o ->
          %{
            order_id: o["orderId"],
            symbol: o["symbol"],
            side: o["side"],
            type: o["type"],
            price: o["price"],
            quantity: o["origQty"],
            executed_quantity: o["executedQty"],
            status: o["status"]
          }
        end)
        Logger.info("Found #{length(orders)} open orders")
        {:ok, %{orders: orders}}

      {:error, {status, %{"msg" => msg}}} ->
        Logger.error("Binance open orders error: #{status} - #{msg}")
        {:error, {status, msg}}

      {:error, reason} ->
        Logger.error("Binance open orders request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
