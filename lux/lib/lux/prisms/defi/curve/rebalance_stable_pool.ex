defmodule Lux.Prisms.Defi.Curve.RebalanceStablePoolPrism do
  @moduledoc """
  Detects Curve pool skew and plans single-coin deposits to harvest positive slippage bonuses.
  """

  use Lux.Prism,
    name: "Rebalance Curve Stable Pool",
    description: "Evaluates coin skew and recommends single-coin deposit strategies for positive slippage",
    input_schema: %{
      type: :object,
      properties: %{
        balances: %{type: :array, items: %{type: :number}, description: "Current coin balances in pool"},
        threshold_pct: %{type: :number, description: "Skew sensitivity threshold", default: 0.05}
      },
      required: ["balances"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        imbalanced: %{type: :boolean},
        preferred_deposit_coin_index: %{type: :integer},
        recommended_action: %{type: :string},
        bonus_estimated_pct: %{type: :number}
      },
      required: ["imbalanced", "preferred_deposit_coin_index", "recommended_action"]
    }

  alias Lux.Defi.Curve.RebalanceEngine

  def handler(input, _ctx) do
    balances = Map.get(input, :balances) || Map.get(input, "balances", [])
    threshold = Map.get(input, :threshold_pct) || Map.get(input, "threshold_pct", 0.05)

    result = RebalanceEngine.evaluate_imbalance(balances, threshold)

    {:ok,
     %{
       imbalanced: result.imbalanced?,
       preferred_deposit_coin_index: result.preferred_deposit_coin_index,
       recommended_action: to_string(result.recommended_action),
       bonus_estimated_pct: result.bonus_estimated_pct
     }}
  end
end
