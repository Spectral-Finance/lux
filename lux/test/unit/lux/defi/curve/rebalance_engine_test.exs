defmodule Lux.Defi.Curve.RebalanceEngineTest do
  use ExUnit.Case, async: true

  alias Lux.Defi.Curve.RebalanceEngine

  describe "evaluate_imbalance/2" do
    test "recommends balanced deposit for healthy balanced pool" do
      result = RebalanceEngine.evaluate_imbalance([1000, 1000, 1000])
      assert result.imbalanced? == false
      assert result.recommended_action == :balanced_deposit
      assert result.bonus_estimated_pct == 0.0
    end

    test "recommends depositing scarce coin with positive bonus" do
      result = RebalanceEngine.evaluate_imbalance([1000, 600, 1000])
      assert result.imbalanced? == true
      assert result.preferred_deposit_coin_index == 1
      assert result.recommended_action == :deposit_scarce
      assert result.bonus_estimated_pct > 0.0
    end

    test "cautions against severe depeg risk" do
      result = RebalanceEngine.evaluate_imbalance([1000, 50, 1000])
      assert result.imbalanced? == true
      assert result.recommended_action == :caution_depeg
    end
  end
end
