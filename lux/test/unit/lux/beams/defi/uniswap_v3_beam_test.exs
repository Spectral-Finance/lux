defmodule Lux.Beams.Defi.UniswapV3BeamTest do
  use ExUnit.Case, async: true

  alias Lux.Beams.Defi.UniswapV3.LiquidityManagementBeam

  describe "run/1" do
    test "executes automated liquidity management beam pipeline" do
      input = %{
        position: %{
          token_id: "pos_beam_test",
          tick_lower: -600,
          tick_upper: 600,
          fee: 3000
        },
        current_tick: 0,
        fee: 3000,
        strategy: "moderate",
        entry_price: 2500.0,
        current_price: 2505.0,
        price_lower: 2350.0,
        price_upper: 2650.0
      }

      assert {:ok, result, execution_log} = LiquidityManagementBeam.run(input)
      assert result.token_id == "pos_beam_test"
      assert result.in_range == true
      assert result.health_score >= 80
      assert result.rebalance_action == "hold"
      assert result.rebalance_viable == true
      assert is_integer(result.optimal_tick_lower)
      assert is_integer(result.optimal_tick_upper)
      assert execution_log.status == :completed
      assert length(execution_log.steps) >= 3
    end
  end
end
