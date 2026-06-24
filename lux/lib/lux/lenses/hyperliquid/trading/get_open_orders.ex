defmodule Lux.Lenses.Hyperliquid.Trading.GetOpenOrders do
  @moduledoc """
  Fetches open orders on Hyperliquid.

  Delegates to `Lux.Prisms.Hyperliquid.HyperliquidOpenOrdersPrism`.

  ## Examples

      iex> GetOpenOrders.focus(%{})
      {:ok, %{orders: [...]}}
  """

  use Lux.Lens,
    name: "Hyperliquid Get Open Orders",
    description: "Fetches open orders on Hyperliquid",
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

  def focus(_params) do
    Lux.Prisms.Hyperliquid.HyperliquidOpenOrdersPrism.run(%{})
  end
end
