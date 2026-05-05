defmodule Lux.Defi.Curve.StablecoinStrategyTest do
  use UnitCase, async: true

  alias Lux.Defi.Curve.StablecoinStrategy

  describe "rank_pools/2" do
    test "ranks pools by net yield after slippage and imbalance penalties" do
      pools = [
        %{
          name: "3pool",
          base_apy: 2.1,
          crv_apy: 1.4,
          volume_apy: 0.3,
          slippage_bps: 4,
          balances: [100, 100, 100],
          gauge_working_supply: 80,
          gauge_total_supply: 100,
          tvl_usd: 10_000_000
        },
        %{
          name: "thin-usd",
          base_apy: 6.0,
          crv_apy: 3.0,
          volume_apy: 0.5,
          slippage_bps: 250,
          balances: [10, 200, 15],
          gauge_working_supply: 5,
          gauge_total_supply: 100,
          tvl_usd: 200_000
        }
      ]

      [best | _] = StablecoinStrategy.rank_pools(pools, max_slippage_bps: 300)

      assert best.name == "3pool"
      assert best.score > 0
      assert best.imbalance_ratio == 0.0
      assert "slippage_bps=4.0" in best.rationale
    end

    test "filters pools by tvl and max slippage" do
      pools = [
        %{name: "too-small", tvl_usd: 99, slippage_bps: 1, balances: [1, 1]},
        %{name: "too-expensive", tvl_usd: 10_000, slippage_bps: 500, balances: [1, 1]},
        %{name: "eligible", tvl_usd: 10_000, slippage_bps: 2, balances: [1, 1]}
      ]

      assert [%{name: "eligible"}] =
               StablecoinStrategy.rank_pools(pools, min_tvl_usd: 1_000, max_slippage_bps: 10)
    end
  end

  describe "rebalance_plan/3" do
    test "creates side-effect-free deposit and withdraw actions" do
      holdings = [
        %{pool: "3pool", value_usd: 700},
        %{pool: "lusd", value_usd: 300}
      ]

      candidates = [
        %{name: "3pool", base_apy: 1, crv_apy: 1, slippage_bps: 1, balances: [1, 1, 1]},
        %{name: "fraxusdc", base_apy: 2, crv_apy: 1, slippage_bps: 2, balances: [1, 1]}
      ]

      plan = StablecoinStrategy.rebalance_plan(holdings, candidates, target_pool_count: 2)

      assert plan.total_value_usd == 1000.0
      assert plan.requires_signature == false
      assert plan.requires_gas == false
      assert %{pool: "3pool", action: :withdraw, delta_usd: 200.0} in plan.actions
      assert %{pool: "fraxusdc", action: :deposit, delta_usd: 500.0} in plan.actions
    end
  end

  describe "rewards_summary/1" do
    test "summarizes claimable CRV without transaction side effects" do
      summary =
        StablecoinStrategy.rewards_summary([
          %{name: "3pool-gauge", claimable_crv: "1.25", claimable_usd: "0.72"},
          %{name: "fraxusdc-gauge", claimable_crv: 2, claimable_usd: 1.1}
        ])

      assert summary.claimable_crv == 3.25
      assert summary.claimable_usd == 1.82
      assert summary.requires_signature == false
      assert summary.requires_gas == false
    end
  end
end
