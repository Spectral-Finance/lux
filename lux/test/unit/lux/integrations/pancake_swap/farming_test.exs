defmodule Lux.Integrations.PancakeSwap.FarmingTest do
  use UnitCase, async: true

  alias Lux.Integrations.PancakeSwap.Farming

  @pools [
    %{
      "id" => "cake-bnb",
      "chain" => :bsc,
      "token0" => %{"symbol" => "CAKE"},
      "token1" => %{"symbol" => "BNB"},
      "tvl_usd" => 5_000_000,
      "fee_apr" => 8,
      "reward_apr" => 24,
      "price_in_range" => true
    },
    %{
      "id" => "thin",
      "chain" => :bsc,
      "token0" => "CAKE",
      "token1" => "USDT",
      "tvl_usd" => 10_000,
      "reward_apr" => 40,
      "impermanent_loss_pct" => 18
    }
  ]

  @position %{
    owner: "0xabc",
    chain: :bsc,
    pool_id: "cake-bnb",
    token_id: "42",
    token0: "CAKE",
    token1: "BNB",
    liquidity_usd: 10_000,
    pending_reward_usd: 75,
    pending_reward_amount: 10,
    reward_token: "CAKE",
    fee_apr: 8,
    farming_apr: 24,
    gas_cost_usd: 3,
    price_in_range: true
  }

  test "normalizes and ranks pools by risk-adjusted APR" do
    [best | _] = Farming.normalize_pools(@pools)

    assert best.id == "cake-bnb"
    assert best.total_apr == 32.0
    assert best.risk_adjusted_apr == 32.0
  end

  test "optimizes pools with chain, TVL, and risk filters" do
    assert [%{id: "cake-bnb"}] =
             Farming.optimize_pools(@pools, chain: :bsc, min_tvl_usd: 100_000, max_risk_score: 20)
  end

  test "builds add and remove liquidity plans" do
    add_plan =
      Farming.add_liquidity_plan(hd(@pools), %{token0: "10", token1: "1"}, slippage_bps: 75)

    assert add_plan.status == :ready

    assert Enum.map(add_plan.steps, & &1.action) == [
             :approve_token,
             :approve_token,
             :add_liquidity,
             :stake_position
           ]

    remove_plan = Farming.remove_liquidity_plan(@position, share_bps: 5_000)

    assert remove_plan.token_id == "42"
    assert Enum.any?(remove_plan.steps, &(&1.action == :collect_fees))
  end

  test "builds harvest and compound plans" do
    harvest_plan = Farming.harvest_plan(@position, recipient: "0xdef")

    assert harvest_plan.expected_reward_usd == 75
    assert [%{action: :harvest_rewards, recipient: "0xdef"}] = harvest_plan.steps

    compound_plan =
      Farming.compound_plan(@position, min_reward_usd: 10, gas_cost_usd: 3, reinvest_pct: 80)

    assert compound_plan.status == :ready
    assert compound_plan.reinvest_usd == 60.0

    assert Enum.map(compound_plan.steps, & &1.action) == [
             :harvest_rewards,
             :swap_reward_to_pool_tokens,
             :increase_liquidity,
             :stake_position
           ]
  end

  test "skips compounding when rewards are not economic" do
    plan =
      Farming.compound_plan(%{@position | pending_reward_usd: 2},
        min_reward_usd: 10,
        gas_cost_usd: 3
      )

    assert plan.status == :skip
    assert plan.reason == :below_reward_threshold
  end

  test "reports risk flags" do
    report =
      @position
      |> Map.merge(%{
        liquidity_usd: 1_000,
        price_in_range: false,
        impermanent_loss_pct: 14,
        pending_reward_usd: 1,
        gas_cost_usd: 3
      })
      |> Farming.risk_report()

    assert report.risk_score > 0

    assert Enum.map(report.flags, & &1.type) == [
             :out_of_range,
             :impermanent_loss,
             :low_liquidity,
             :uneconomic_harvest
           ]
  end

  test "builds cross-chain migration plan" do
    plan = Farming.bridge_plan(@position, :base, bridge: :layerzero)

    assert plan.status == :ready
    assert plan.source_chain == :bsc
    assert plan.target_chain == :base
    assert Enum.any?(plan.steps, &(&1.action == :bridge_assets))
  end
end
