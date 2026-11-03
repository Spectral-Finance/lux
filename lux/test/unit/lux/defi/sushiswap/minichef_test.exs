defmodule Lux.Defi.SushiSwap.MiniChefTest do
  use UnitCase, async: true

  alias Lux.Defi.SushiSwap.MiniChef

  @pool %{
    pid: 0,
    lp_token: "0xLPToken",
    alloc_point: 100,
    acc_sushi_per_share: 2_000_000_000_000,
    total_staked: 5_000_000_000_000_000_000
  }

  @user %{
    user_address: "0xUser",
    pid: 0,
    amount: 1_000_000_000_000_000_000,
    reward_debt: 1_000_000_000_000_000_000
  }

  describe "calculate_pending_sushi/2" do
    test "calculates pending SUSHI accurately" do
      # 1e18 * 2e12 / 1e12 = 2e18. Pending = 2e18 - 1e18 = 1e18 = 1.0 SUSHI
      pending = MiniChef.calculate_pending_sushi(@user, @pool)
      assert pending == 1.0
    end
  end

  describe "deposit/3" do
    test "updates staked amount and harvests pending rewards" do
      deposit_amt = 500_000_000_000_000_000
      {:ok, updated_user, updated_pool, pending} = MiniChef.deposit(@user, @pool, deposit_amt)

      assert updated_user.amount == 1_500_000_000_000_000_000
      assert updated_pool.total_staked == 5_500_000_000_000_000_000
      assert pending == 1.0
    end
  end

  describe "harvest/2" do
    test "harvests pending rewards without changing balance" do
      {:ok, updated_user, pending} = MiniChef.harvest(@user, @pool)

      assert pending == 1.0
      assert updated_user.amount == @user.amount
    end
  end
end
