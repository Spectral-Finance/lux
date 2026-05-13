defmodule Lux.Integrations.Curve.StablecoinTest do
  use UnitCase, async: true

  alias Lux.Integrations.Curve.Stablecoin

  describe "position_summary/1" do
    test "normalizes positions and aggregates value, stake, apr, and rewards" do
      summary =
        Stablecoin.position_summary([
          %{
            pool: "3pool",
            gauge: "0xgauge",
            lp_balance: "10",
            staked_balance: "8",
            share_value_usd: "1000",
            base_apr: 0.04,
            crv_apr: 0.02,
            rewards: [%{token: "crv", amount: "12.5"}],
            coins: [%{symbol: "usdc", balance: "500"}]
          },
          %{
            pool: "fraxusdc",
            lp_tokens: 5,
            gauge_staked: 5,
            value_usd: 500,
            base_apr: 0.03,
            crv_apr: 0.01,
            rewards: [%{"token" => "CRV", "amount" => 2.5}]
          }
        ])

      assert summary.position_count == 2
      assert summary.total_value_usd == 1500.0
      assert summary.total_lp_balance == 15.0
      assert summary.total_staked_balance == 13.0
      assert summary.weighted_apr == 0.053333
      assert summary.rewards == %{"CRV" => 15.0}
      assert hd(summary.positions).coins == [%{symbol: "USDC", balance: 500.0}]
    end
  end

  describe "gauge_plan/2" do
    test "builds stake, unstake, and rewards claim action plans" do
      assert {:ok, stake} =
               Stablecoin.gauge_plan(:stake, %{
                 gauge: "0xgauge",
                 lp_token: "0xlp",
                 amount: "12.5",
                 user: "0xuser"
               })

      assert stake.action == :stake
      assert stake.amount == 12.5
      assert stake.requires_signature?
      assert stake.side_effect_free? == false

      assert {:ok, claim} = Stablecoin.gauge_plan(:claim_rewards, %{gauge: "0xgauge"})
      refute Map.has_key?(claim, :amount)

      assert Stablecoin.gauge_plan(:unstake, %{gauge: "0xgauge", amount: 0}) ==
               {:error, "Curve gauge stake/unstake amount must be positive"}
    end
  end

  describe "reward_projection/1" do
    test "estimates annual CRV reward value and APR" do
      projection =
        Stablecoin.reward_projection(%{
          staked_value_usd: 1000,
          crv_per_day: 2,
          crv_price_usd: 0.5,
          boost_multiplier: 1.5
        })

      assert projection.annual_reward_value_usd == 547.5
      assert projection.crv_apr == 0.5475
    end
  end

  describe "pool_analysis/2" do
    test "scores pools and flags risk" do
      analysis =
        Stablecoin.pool_analysis(
          [
            %{
              pool: "3pool",
              tvl_usd: 500_000_000,
              base_apr: 0.025,
              crv_apr: 0.015,
              volume_24h_usd: 20_000_000,
              virtual_price: 1.02,
              imbalance_bps: 20
            },
            %{
              pool: "tiny",
              tvl_usd: 500_000,
              base_apr: 0.05,
              crv_apr: 0.01,
              volume_24h_usd: 1000,
              virtual_price: 1,
              imbalance_bps: 250
            }
          ],
          %{min_tvl_usd: 0}
        )

      assert analysis.pool_count == 2
      assert analysis.best_pool.pool == "3pool"
      assert :low_liquidity in Enum.find(analysis.pools, &(&1.pool == "tiny")).risk_flags
      assert :pool_imbalance in Enum.find(analysis.pools, &(&1.pool == "tiny")).risk_flags
    end
  end

  describe "slippage_check/2" do
    test "evaluates slippage against policy" do
      accepted = Stablecoin.slippage_check(%{expected_amount: 1000, minimum_amount: 997}, %{max_slippage_bps: 40})
      rejected = Stablecoin.slippage_check(%{expected_amount: 1000, minimum_amount: 990}, %{max_slippage_bps: 40})

      assert accepted.slippage_bps == 30.0
      assert accepted.allowed?
      assert rejected.slippage_bps == 100.0
      refute rejected.allowed?
    end
  end

  describe "rebalance_plan/3" do
    test "recommends liquidity moves toward target weights" do
      plan =
        Stablecoin.rebalance_plan(
          [
            %{pool: "3pool", share_value_usd: 1200},
            %{pool: "fraxusdc", share_value_usd: 800}
          ],
          %{"3pool" => 0.5, "fraxusdc" => 0.5},
          %{threshold_usd: 50}
        )

      assert plan.total_value_usd == 2000.0
      assert plan.requires_signature?
      assert %{pool: "3pool", action: :remove_liquidity, amount_usd: 200.0} in plan.moves
      assert %{pool: "fraxusdc", action: :add_liquidity, amount_usd: 200.0} in plan.moves
    end
  end

  describe "yield_report/1" do
    test "combines current positions and best available pools" do
      report =
        Stablecoin.yield_report(%{
          positions: [
            %{pool: "3pool", share_value_usd: 1000, base_apr: 0.04, crv_apr: 0.02}
          ],
          pools: [
            %{pool: "3pool", tvl_usd: 500_000_000, base_apr: 0.04, crv_apr: 0.02},
            %{pool: "fraxusdc", tvl_usd: 200_000_000, base_apr: 0.05, crv_apr: 0.03}
          ]
        })

      assert report.current_weighted_apr == 0.06
      assert report.best_available_apr == 0.08
      assert report.estimated_annual_yield_usd == 60.0
    end
  end
end
