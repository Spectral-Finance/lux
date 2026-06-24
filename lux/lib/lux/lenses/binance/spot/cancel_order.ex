defmodule Lux.Lenses.Binance.Spot.CancelOrder do
  @moduledoc """
  Cancels an open order on Binance.

  ## Examples

      iex> CancelOrder.focus(%{symbol: "BTCUSDT", order_id: 1234567})
      {:ok, %{status: "CANCELED"}}
  """

  alias Lux.Integrations.Binance
  require Logger

  use Lux.Lens,
    name: "Binance Cancel Order",
    description: "Cancels an open order on Binance",
    url: "#{Binance.base_url()}/api/v3/order",
    method: :delete,
    headers: Binance.headers(),
    auth: Binance.auth(),
    schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Trading pair"},
        order_id: %{type: :integer, description: "Order ID to cancel"}
      },
      required: ["symbol", "order_id"]
    }

  def after_focus(body) when is_map(body) do
    {:ok, body}
  end

  def after_focus(body) do
    {:error, %{error: "Unexpected response", raw: body}}
  end
end
