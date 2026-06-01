defmodule Lux.Prisms.Binance.Spot.CancelOrder do
  @moduledoc """
  A prism for cancelling an open spot order on Binance.

  ## Examples

      iex> CancelOrder.handler(%{
      ...>   symbol: "BTCUSDT",
      ...>   order_id: 12345
      ...> }, %{name: "TradingAgent"})
      {:ok, %{order_id: 12345, symbol: "BTCUSDT", status: "CANCELED"}}
  """

  use Lux.Prism,
    name: "Binance Cancel Spot Order",
    description: "Cancels an open spot order on Binance by order ID",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Trading pair, e.g. BTCUSDT"},
        order_id: %{type: :integer, description: "The order ID to cancel"},
        api_key: %{type: :string, description: "Binance API key"},
        secret_key: %{type: :string, description: "Binance secret key"}
      },
      required: ["symbol", "order_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        order_id: %{type: :integer, description: "Cancelled order ID"},
        symbol: %{type: :string, description: "Trading pair"},
        status: %{type: :string, description: "CANCELED"}
      },
      required: ["order_id", "symbol", "status"]
    }

  alias Lux.Integrations.Binance.Client
  require Logger

  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown"

    with {:ok, symbol} <- fetch_string(params, :symbol),
         {:ok, order_id} <- fetch_integer(params, :order_id) do

      Logger.info("Agent #{agent_name} cancelling order #{order_id} on #{symbol}")

      case Client.request(:delete, "/api/v3/order", %{
        signed: true,
        api_key: params[:api_key],
        secret_key: params[:secret_key],
        params: %{symbol: symbol, orderId: order_id}
      }) do
        {:ok, resp} ->
          {:ok, %{
            order_id: resp["orderId"],
            symbol: resp["symbol"],
            status: resp["status"],
            side: resp["side"],
            type: resp["type"]
          }}

        {:error, {:bad_request, code, msg}} ->
          {:error, "Cancel rejected (#{code}): #{msg}"}

        {:error, err} ->
          {:error, "Failed to cancel order: #{inspect(err)}"}
      end
    end
  end

  defp fetch_string(params, key) do
    case Map.fetch(params, key) do
      {:ok, val} when is_binary(val) and val != "" -> {:ok, val}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp fetch_integer(params, key) do
    case Map.fetch(params, key) do
      {:ok, val} when is_integer(val) -> {:ok, val}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
