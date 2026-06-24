defmodule Lux.Lenses.Hyperliquid.Trading.GetPositions do
  @moduledoc """
  Fetches current open positions on Hyperliquid.

  Delegates to `Lux.Prisms.Hyperliquid.HyperliquidUserStatePrism` for position data.

  ## Examples

      iex> GetPositions.focus(%{})
      {:ok, %{asset_positions: [...]}}
  """

  use Lux.Lens,
    name: "Hyperliquid Get Positions",
    description: "Fetches current Hyperliquid trading positions",
    schema: %{
      type: :object,
      properties: %{},
      required: []
    }

  def focus(_params) do
    Lux.Prisms.Hyperliquid.HyperliquidUserStatePrism.run(%{})
  end
end
