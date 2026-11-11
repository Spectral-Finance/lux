defmodule Lux.Prisms.Curve.StablecoinPoolPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Curve.StablecoinPoolPrism
  alias Lux.Prisms.Curve.StablecoinPoolPrism.{GaugePosition, PoolState}

  describe "compute_d/2 and estimate_swap/4" do
    test "computes Curve 3pool StableSwap invariant D and low-slippage swap output" do
      pool = %PoolState{
        pool_id: "3pool",
        name: "Curve.fi DAI/USDC/USDT",
        coins: ["DAI", "USDC", "USDT"],
        balances: [50_000_000.0, 50_000_000.0, 50_000_000.0],
        amp: 200,
        fee_bps: 4.0
      }

      assert {:ok, d} = StablecoinPoolPrism.compute_d(pool.balances, pool.amp)
      assert_in_delta d, 150_000_000.0, 1.0

      assert {:ok, swap} = StablecoinPoolPrism.estimate_swap(pool, 0, 1, 100_000.0)
      assert swap.coin_in == "DAI"
      assert swap.coin_out == "USDC"
      assert swap.dy_net > 99_950.0
      assert swap.slippage_bps < 5.0
    end
  end

  describe "evaluate_gauge_yield/2 and plan_rebalance/2" do
    test "calculates 2.5x veCRV gauge boost and recommends optimal pool rebalance" do
      pool_3crv = %PoolState{
        pool_id: "3pool",
        name: "DAI/USDC/USDT",
        coins: ["DAI", "USDC", "USDT"],
        balances: [40_000_000.0, 40_000_000.0, 40_000_000.0],
        amp: 200,
        base_apy: 3.2,
        crv_apr_min: 1.8,
        crv_apr_max: 4.5,
        extra_rewards_apr: 0.5
      }

      pool_crvusd = %PoolState{
        pool_id: "crvusd-usdc",
        name: "crvUSD/USDC",
        coins: ["crvUSD", "USDC"],
        balances: [25_000_000.0, 25_000_000.0],
        amp: 500,
        base_apy: 5.4,
        crv_apr_min: 3.0,
        crv_apr_max: 7.5,
        extra_rewards_apr: 1.2
      }

      pos = %GaugePosition{
        pool_id: "crvusd-usdc",
        lp_staked: 100_000.0,
        pool_total_lp: 10_000_000.0,
        user_vecrv: 250_000.0,
        total_vecrv: 10_000_000.0
      }

      assert {:ok, yield_info} = StablecoinPoolPrism.evaluate_gauge_yield(pool_crvusd, pos)
      assert yield_info.boost_factor == 2.5
      assert yield_info.boosted_crv_apr == 7.5
      assert yield_info.total_apy == 14.1

      assert {:ok, plan} =
               StablecoinPoolPrism.plan_rebalance(
                 [{pool_3crv, pos}, {pool_crvusd, pos}],
                 8.2
               )

      assert plan.recommended_pool == "crvusd-usdc"
      assert plan.should_rebalance == true
      assert plan.expected_apy_gain > 5.0
    end
  end
end
