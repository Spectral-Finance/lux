defmodule Lux.Beams.Defi.CurveBeamTest do
  use ExUnit.Case, async: true

  alias Lux.Beams.Defi.Curve.StablecoinManagementBeam

  @unit 1_000_000_000_000_000_000

  describe "run/1" do
    test "executes automated Curve stablecoin management beam pipeline" do
      input = %{
        pool_id: "3pool",
        balances: [1000 * @unit, 1000 * @unit, 1000 * @unit],
        amp: 2000,
        user_lp: 5000.0,
        total_gauge_lp: 500_000.0,
        user_vecrv: 10_000.0,
        unclaimed_crv: 50.0
      }

      assert {:ok, result, execution_log} = StablecoinManagementBeam.run(input)
      assert result.pool_id == "3pool"
      assert result.virtual_price >= 1.0
      assert result.pool_health_score == 100
      assert result.imbalanced == false
      assert result.gauge_boost >= 1.0
      assert result.compound_viable == true
      assert execution_log.status == :completed
      assert length(execution_log.steps) >= 4
    end
  end
end
