defmodule Lux.Defi.Curve.PositionManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Defi.Curve.PositionManager

  @unit 1_000_000_000_000_000_000

  setup do
    pos = PositionManager.create_position("0x95222290dd7278aa3ddd389cc1e1d165cc4bafe5", "3pool", lp_balance: 100 * @unit)
    %{position: pos}
  end

  describe "create_position/3" do
    test "initializes position with unique id and owner", %{position: pos} do
      assert String.starts_with?(pos.id, "curve_pos_")
      assert pos.pool_id == "3pool"
      assert pos.lp_balance == 100 * @unit
    end
  end

  describe "withdraw_balanced/4" do
    test "withdraws proportional balances", %{position: pos} do
      current_balances = [1000 * @unit, 1000 * @unit, 1000 * @unit]
      total_lp = 3000 * @unit

      assert {:ok, updated_pos, withdrawn} = PositionManager.withdraw_balanced(pos, 30 * @unit, current_balances, total_lp)
      assert updated_pos.lp_balance == 70 * @unit
      assert length(withdrawn) == 3
      assert hd(withdrawn) == 10 * @unit
    end
  end

  describe "position_value_usd/2" do
    test "calculates USD valuation based on virtual price", %{position: pos} do
      # 100 LP * 1.05 virtual price = $105.00
      val = PositionManager.position_value_usd(pos, 1.05)
      assert val == 105.0
    end
  end
end
