defmodule Lux.Defi.Curve.GaugeManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Defi.Curve.PositionManager
  alias Lux.Defi.Curve.GaugeManager

  @unit 1_000_000_000_000_000_000

  setup do
    pos = PositionManager.create_position("0x95222290dd7278aa3ddd389cc1e1d165cc4bafe5", "3pool", lp_balance: 50 * @unit)
    %{position: pos}
  end

  describe "stake/2 and unstake/2" do
    test "moves LP tokens into and out of gauge", %{position: pos} do
      assert {:ok, staked_pos} = GaugeManager.stake(pos, 30 * @unit)
      assert staked_pos.lp_balance == 20 * @unit
      assert staked_pos.staked_in_gauge == 30 * @unit

      assert {:ok, unstaked_pos} = GaugeManager.unstake(staked_pos, 10 * @unit)
      assert unstaked_pos.lp_balance == 30 * @unit
      assert unstaked_pos.staked_in_gauge == 20 * @unit
    end

    test "rejects staking more than available balance", %{position: pos} do
      assert {:error, :insufficient_lp} = GaugeManager.stake(pos, 100 * @unit)
    end
  end

  describe "calculate_boost/4" do
    test "calculates boost and max boost flag" do
      metrics = GaugeManager.calculate_boost(1000.0, 50_000.0, 500_000.0, 1_000_000.0)
      assert metrics.boost == 2.5
      assert metrics.max_boosted? == true
    end
  end
end
