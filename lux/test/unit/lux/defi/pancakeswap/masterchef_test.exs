defmodule Lux.Defi.PancakeSwap.MasterChefTest do
  use UnitCase, async: true

  alias Lux.Defi.PancakeSwap.MasterChef

  @pool %{
    pid: 1,
    lp_token: "0xPoolAddress",
    alloc_point: 100,
    total_alloc_point: 1000,
    acc_cake_per_share: 2_000_000_000_000,
    cake_per_second: 1.0,
    total_staked: 10_000_000_000_000_000_000
  }

  @user %{
    user_address: "0xUserAddress",
    pid: 1,
    amount: 1_000_000_000_000_000_000,
    reward_debt: 1_000_000_000_000_000_000
  }

  describe "calculate_pending_cake/2" do
    test "calculates accrued pending cake correctly" do
      # amount = 1e18, acc = 2e12, accumulated = 1e18 * 2e12 / 1e12 = 2e18
      # pending = 2e18 - 1e18 = 1e18 = 1.0 CAKE
      pending = MasterChef.calculate_pending_cake(@user, @pool)
      assert pending == 1.0
    end

    test "returns 0.0 when user has zero staked" do
      user = %{@user | amount: 0, reward_debt: 0}
      assert MasterChef.calculate_pending_cake(user, @pool) == 0.0
    end
  end

  describe "deposit/3" do
    test "deposits tokens and updates stake and pool totals" do
      deposit_amt = 500_000_000_000_000_000
      {:ok, updated_user, updated_pool, pending} = MasterChef.deposit(@user, @pool, deposit_amt)

      assert updated_user.amount == 1_500_000_000_000_000_000
      assert updated_pool.total_staked == 10_500_000_000_000_000_000
      assert pending == 1.0
    end
  end

  describe "withdraw/3" do
    test "withdraws valid amount" do
      withdraw_amt = 400_000_000_000_000_000
      {:ok, updated_user, updated_pool, pending} = MasterChef.withdraw(@user, @pool, withdraw_amt)

      assert updated_user.amount == 600_000_000_000_000_000
      assert updated_pool.total_staked == 9_600_000_000_000_000_000
      assert pending == 1.0
    end

    test "returns error if withdrawal exceeds balance" do
      withdraw_amt = 2_000_000_000_000_000_000
      assert {:error, :insufficient_staked_balance} = MasterChef.withdraw(@user, @pool, withdraw_amt)
    end
  end

  describe "harvest/2" do
    test "harvests rewards and updates reward debt" do
      {:ok, updated_user, pending} = MasterChef.harvest(@user, @pool)
      assert pending == 1.0
      assert updated_user.amount == @user.amount
      assert updated_user.reward_debt == 2_000_000_000_000_000_000
    end
  end
end
