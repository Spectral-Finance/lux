defmodule Lux.Integrations.CurveFinance.StablecoinsTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.CurveFinance.Stablecoins

  @payload %{
    "data" => %{
      "poolData" => [
        %{
          "name" => "3pool",
          "address" => "0xpool",
          "lpTokenAddress" => "0xlp",
          "gaugeAddress" => "0xgauge",
          "coins" => [
            %{"symbol" => "DAI", "poolBalance" => "1000000", "usdPrice" => "1"},
            %{"symbol" => "USDC", "poolBalance" => "1000000", "usdPrice" => "1"},
            %{"symbol" => "USDT", "poolBalance" => "1000000", "usdPrice" => "1"}
          ],
          "usdTotal" => "3000000",
          "volumeUSD" => "500000",
          "fee" => "4000000",
          "baseApy" => "0.015",
          "gaugeCrvApy" => "0.025",
          "gaugeRewardsApy" => "0.01",
          "virtualPrice" => "1.02",
          "gaugeRewards" => [%{"tokenAddress" => "0xcrv"}]
        },
        %{
          "name" => "ETH/BTC",
          "address" => "0xvolatile",
          "coins" => [
            %{"symbol" => "ETH", "poolBalance" => "10", "usdPrice" => "3000"},
            %{"symbol" => "WBTC", "poolBalance" => "1", "usdPrice" => "60000"}
          ],
          "usdTotal" => "90000"
        }
      ]
    }
  }

  describe "pool analysis" do
    test "normalizes and filters stablecoin pools" do
      assert [%{name: "3pool", fee_pct: fee, max_coin_pct: max_coin_pct}] =
               Stablecoins.stablecoin_pools(@payload)

      assert fee == 0.0004
      assert_in_delta max_coin_pct, 0.3333, 0.001
    end

    test "ranks stable pools by liquidity and yield policy" do
      assert [%{name: "3pool", score: score, total_apy: 0.05}] =
               Stablecoins.pool_analysis(@payload,
                 policy: %{min_tvl_usd: 1_000_000, min_base_apy: 0.01}
               )

      assert score > 0
    end
  end

  describe "gauge and rewards" do
    test "builds gauge staking plan" do
      [pool] = Stablecoins.stablecoin_pools(@payload)

      assert {:ok, plan} = Stablecoins.gauge_staking_plan(pool, "25.5")
      assert plan.action == :stake_lp_tokens
      assert plan.gauge_address == "0xgauge"
      assert plan.expected_reward_tokens == ["0xcrv"]
    end

    test "rejects pool without a gauge" do
      assert {:error, "pool has no gauge"} =
               Stablecoins.gauge_staking_plan(%{name: "No Gauge", coins: ["DAI", "USDC"]}, 10)
    end

    test "ranks reward opportunities" do
      assert [%{name: "3pool", reward_score: reward_score}] =
               Stablecoins.rewards_optimization(@payload)

      assert reward_score == 0.035
    end
  end

  describe "position monitoring and controls" do
    test "monitors positions and weighted APY" do
      monitor =
        Stablecoins.position_monitor(
          [%{pool_address: "0xpool", lp_amount: 100, value_usd: 102}],
          @payload
        )

      assert monitor.total_value_usd == 102.0
      assert monitor.weighted_apy == 0.05
      assert [%{pool: "3pool"}] = monitor.positions
    end

    test "creates rebalance actions from target allocation drift" do
      plan =
        Stablecoins.rebalance_plan(
          %{USDC: 0.60, DAI: 0.20, USDT: 0.20},
          policy: %{target_allocations: %{USDC: 0.34, DAI: 0.33, USDT: 0.33}},
          threshold_pct: 0.03
        )

      assert plan.status == :rebalance_required
      assert Enum.any?(plan.actions, &match?(%{asset: :USDC, action: :reduce}, &1))
      assert Enum.any?(plan.actions, &match?(%{asset: :DAI, action: :increase}, &1))
    end

    test "blocks excessive slippage" do
      assert {:ok, approved} =
               Stablecoins.slippage_check(%{amount_in: 1000, expected_out: 999, min_out: 998})

      assert approved.decision == :approved

      assert {:error, blocked} =
               Stablecoins.slippage_check(%{amount_in: 1000, expected_out: 1000, min_out: 990})

      assert blocked.decision == :blocked
    end

    test "ranks candidate routes by slippage" do
      [best | rest] =
        Stablecoins.slippage_optimization([
          %{amount_in: 1000, expected_out: 1000, min_out: 990, route: [:USDC, :USDT]},
          %{amount_in: 1000, expected_out: 998, min_out: 997, route: [:USDC, :DAI]}
        ])

      assert best.status == :approved
      assert best.route == [:USDC, :DAI]
      assert [%{status: :blocked}] = rest
    end
  end

  describe "dashboard/2" do
    test "builds compact stablecoin management dashboard" do
      dashboard =
        Stablecoins.dashboard(
          %{
            pools: @payload,
            positions: [%{pool_address: "0xpool", lp_amount: 100, value_usd: 102}],
            allocations: %{USDC: 0.60}
          },
          policy: %{target_allocations: %{USDC: 0.34}}
        )

      assert [%{name: "3pool"}] = dashboard.top_pools
      assert dashboard.positions.total_value_usd == 102.0
      assert dashboard.rebalance.status == :rebalance_required
    end
  end
end
