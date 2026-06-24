defmodule Lux.Lenses.Hyperliquid.Trading.CancelOrder do
  @moduledoc """
  Cancels an open order on Hyperliquid.

  Delegates to `Lux.Prisms.Hyperliquid.HyperliquidCancelOrderPrism`.

  ## Examples

      iex> CancelOrder.focus(%{order_id: "..."})
      {:ok, %{status: "success"}}
  """

  use Lux.Lens,
    name: "Hyperliquid Cancel Order",
    description: "Cancels an open order on Hyperliquid",
    schema: %{
      type: :object,
      properties: %{
        order_id: %{type: :string, description: "The ID of the order to cancel"}
      },
      required: ["order_id"]
    }

  def focus(%{order_id: order_id}) do
    Lux.Prisms.Hyperliquid.HyperliquidCancelOrderPrism.run(%{oid: order_id})
  end
end
