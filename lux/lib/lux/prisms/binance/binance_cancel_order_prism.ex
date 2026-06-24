defmodule Lux.Prisms.Binance.CancelOrderPrism do
  @moduledoc """
  A prism for cancelling orders on the Binance exchange.

  ## Examples

      iex> Lux.Prisms.Binance.CancelOrderPrism.handler(%{
      ...>   symbol: "BTCUSDT",
      ...>   order_id: 123456789
      ...> }, %{name: "Agent"})
      {:ok, %{cancelled: true, order_id: 123456789, symbol: "BTCUSDT", status: "CANCELED"}}
  """

  use Lux.Prism,
    name: "Binance Cancel Order",
    description: "Cancels an existing order on the Binance exchange",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g., 'BTCUSDT')"
        },
        order_id: %{
          type: :integer,
          description: "Binance order ID to cancel"
        },
        client_order_id: %{
          type: :string,
          description: "Client order ID (alternative to order_id)"
        },
        futures: %{
          type: :boolean,
          description: "If true, cancel on Futures market",
          default: false
        }
      },
      required: ["symbol"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        cancelled: %{type: :boolean, description: "Whether order was successfully cancelled"},
        order_id: %{type: :integer, description: "Cancelled order ID"},
        symbol: %{type: :string, description: "Trading pair symbol"},
        status: %{type: :string, description: "Order status after cancellation"}
      },
      required: ["cancelled", "symbol"]
    }

  alias Lux.Integrations.Binance
  require Logger

  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    futures = Map.get(params, :futures, false)
    Logger.info("Agent #{agent_name} cancelling order for #{params.symbol}")

    path = if futures, do: "/fapi/v1/order", else: "/api/v3/order"
    cancel_params = build_cancel_params(params)

    case Binance.delete(path, cancel_params, futures: futures) do
      {:ok, %{"orderId" => order_id, "symbol" => symbol, "status" => status}} ->
        Logger.info("Order #{order_id} cancelled successfully for #{symbol}")
        {:ok, %{cancelled: true, order_id: order_id, symbol: symbol, status: status}}

      {:error, {status_code, %{"msg" => msg}}} ->
        Logger.error("Binance cancel error: #{status_code} - #{msg}")
        {:error, {status_code, msg}}

      {:error, reason} ->
        Logger.error("Binance cancel request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_cancel_params(params) do
    base = %{symbol: params.symbol}

    cond do
      Map.has_key?(params, :order_id) -> Map.put(base, :orderId, params.order_id)
      Map.has_key?(params, :client_order_id) -> Map.put(base, :origClientOrderId, params.client_order_id)
      true -> base
    end
  end
end
