defmodule Lux.Lenses.Binance.Spot.PlaceOrder do
  @moduledoc """
  Places a spot order on Binance.

  ## Examples

      iex> PlaceOrder.focus(%{symbol: "BTCUSDT", side: "BUY", type: "LIMIT", quantity: "0.001", price: "50000"})
      {:ok, %{orderId: 1234567, status: "NEW"}}
  """

  alias Lux.Integrations.Binance
  require Logger

  use Lux.Lens,
    name: "Binance Place Order",
    description: "Places a spot order on Binance",
    url: "#{Binance.base_url()}/api/v3/order",
    method: :post,
    headers: Binance.headers(),
    auth: Binance.auth(),
    schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Trading pair"},
        side: %{type: :string, enum: ["BUY", "SELL"]},
        type: %{type: :string, enum: ["LIMIT", "MARKET", "STOP_LOSS", "STOP_LOSS_LIMIT", "TAKE_PROFIT", "TAKE_PROFIT_LIMIT"]},
        quantity: %{type: :string, description: "Order quantity"},
        price: %{type: :string, description: "Order price (required for LIMIT)"},
        time_in_force: %{type: :string, enum: ["GTC", "IOC", "FOK"], default: "GTC"}
      },
      required: ["symbol", "side", "type", "quantity"]
    }

  def after_focus(body) when is_map(body) do
    {:ok, body}
  end

  def after_focus(body) do
    {:error, %{error: "Unexpected response", raw: body}}
  end
end
