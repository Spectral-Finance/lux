defmodule Lux.Prisms.Trading.Hyperliquid.CheckLiquidationRiskPrism do
  @moduledoc """
  Monitors liquidation distance percentage and classifies risk tier for open positions.
  """

  use Lux.Prism,
    name: "Check Hyperliquid Liquidation Risk",
    description: "Evaluates liquidation proximity distance percentage and protective action tier",
    input_schema: %{
      type: :object,
      properties: %{
        position: %{
          type: :object,
          properties: %{
            coin: %{type: :string},
            mark_px: %{type: :number},
            liquidation_px: %{type: :number},
            sz: %{type: :number}
          },
          required: ["mark_px", "liquidation_px"]
        }
      },
      required: ["position"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        distance_pct: %{type: :number},
        tier: %{type: :string},
        action: %{type: :string},
        alert: %{type: :string}
      },
      required: ["distance_pct", "tier", "action"]
    }

  alias Lux.Trading.Hyperliquid.LiquidationProtector

  def handler(input, _ctx) do
    raw_pos = Map.get(input, :position) || Map.get(input, "position", %{})

    pos = %{
      coin: Map.get(raw_pos, :coin) || Map.get(raw_pos, "coin", "ETH"),
      mark_px: (Map.get(raw_pos, :mark_px) || Map.get(raw_pos, "mark_px", 1.0)) * 1.0,
      liquidation_px: (Map.get(raw_pos, :liquidation_px) || Map.get(raw_pos, "liquidation_px", 0.0)) * 1.0,
      sz: (Map.get(raw_pos, :sz) || Map.get(raw_pos, "sz", 0.0)) * 1.0
    }

    result = LiquidationProtector.evaluate_risk_tier(pos)

    {:ok,
     %{
       distance_pct: result.distance_pct,
       tier: to_string(result.tier),
       action: to_string(result.action),
       alert: result.alert || ""
     }}
  end
end
