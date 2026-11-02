defmodule Lux.Prisms.Trading.Hyperliquid.TrackPositionsPrism do
  @moduledoc """
  Calculates position valuation, unrealized PnL, ROE percentage, and liquidation price.
  """

  use Lux.Prism,
    name: "Track Hyperliquid Positions",
    description: "Calculates notional value, unrealized PnL, ROE %, and liquidation prices",
    input_schema: %{
      type: :object,
      properties: %{
        coin: %{type: :string, description: "Coin symbol"},
        sz: %{type: :number, description: "Position size (positive for long, negative for short)"},
        entry_px: %{type: :number, description: "Average entry price"},
        mark_px: %{type: :number, description: "Current mark price"},
        leverage: %{type: :integer, default: 10}
      },
      required: ["coin", "sz", "entry_px"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        coin: %{type: :string},
        direction: %{type: :string},
        sz: %{type: :number},
        notional: %{type: :number},
        unrealized_pnl: %{type: :number},
        roe_pct: %{type: :number},
        liquidation_px: %{type: :number}
      },
      required: ["coin", "direction", "notional", "unrealized_pnl", "roe_pct", "liquidation_px"]
    }

  alias Lux.Trading.Hyperliquid.PositionTracker

  def handler(input, _ctx) do
    case PositionTracker.track_position(input) do
      {:ok, pos} ->
        {:ok,
         %{
           coin: pos.coin,
           direction: to_string(pos.direction),
           sz: pos.sz,
           notional: pos.notional,
           unrealized_pnl: pos.unrealized_pnl,
           roe_pct: pos.roe_pct,
           liquidation_px: pos.liquidation_px
         }}

      {:error, reason} ->
        {:error, "Position tracking failed: #{inspect(reason)}"}
    end
  end
end
