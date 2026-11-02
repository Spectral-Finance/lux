defmodule Lux.Defi.Curve.MathTest do
  use ExUnit.Case, async: true

  alias Lux.Defi.Curve.Math

  @unit 1_000_000_000_000_000_000

  describe "get_d/2" do
    test "calculates invariant D equal to sum of balances when balanced" do
      balances = [1000 * @unit, 1000 * @unit, 1000 * @unit]
      amp = 2000

      d = Math.get_d(balances, amp)
      # In a perfectly balanced pool, D equals the sum of balances
      expected_sum = 3000 * @unit
      assert_in_delta d, expected_sum, 1000
    end

    test "calculates positive D when imbalanced" do
      balances = [1500 * @unit, 800 * @unit, 700 * @unit]
      amp = 2000

      d = Math.get_d(balances, amp)
      assert d > 0
    end
  end

  describe "get_dy/6" do
    test "calculates swap output amount with fee deduction" do
      balances = [1000 * @unit, 1000 * @unit, 1000 * @unit]
      amp = 2000
      dx = 10 * @unit

      dy = Math.get_dy(0, 1, dx, balances, amp, 0.0004)
      # StableSwap has very low slippage: dy should be slightly less than dx (due to fee and minimal curve curvature)
      assert dy > 0
      assert dy < dx
      assert_in_delta dy, dx, round(0.01 * dx)
    end
  end

  describe "calc_lp_mint/4" do
    test "calculates correct LP tokens minted on balanced deposit" do
      balances = [1000 * @unit, 1000 * @unit]
      amp = 1000
      deposit = [100 * @unit, 100 * @unit]
      total_lp = 2000 * @unit

      minted = Math.calc_lp_mint(deposit, balances, amp, total_lp)
      # 10% increase in pool balances yields ~10% increase in LP tokens (200 * @unit)
      assert_in_delta minted, 200 * @unit, 1000
    end
  end

  describe "calculate_gauge_boost/4" do
    test "returns 1.0x boost for 0 veCRV" do
      assert Math.calculate_gauge_boost(1000.0, 100_000.0, 0.0, 1_000_000.0) == 1.0
    end

    test "scales up to 2.5x max boost when veCRV is abundant" do
      assert Math.calculate_gauge_boost(1000.0, 100_000.0, 500_000.0, 1_000_000.0) == 2.5
    end
  end
end
