defmodule Lux.Integration.PancakeSwapFarmingWorkflowTest do
  use IntegrationCase, async: true

  alias Lux.Integrations.PancakeSwap.Farming

  @tag :integration
  test "builds farming workflow from pools, position, compound, risk, and bridge data" do
    [pool] =
      Farming.optimize_pools(
        [
          %{
            id: "cake-bnb",
            chain: :bsc,
            token0: "CAKE",
            token1: "BNB",
            tvl_usd: 5_000_000,
            fee_apr: 8,
            reward_apr: 24,
            price_in_range: true
          }
        ],
        min_tvl_usd: 100_000
      )

    position =
      Farming.position(%{
        owner: "0xabc",
        chain: :bsc,
        pool: pool,
        token_id: "42",
        liquidity_usd: 250_000,
        pending_reward_usd: 75,
        gas_cost_usd: 3,
        price_in_range: true
      })

    compound = Farming.compound_plan(position, min_reward_usd: 10)
    risk = Farming.risk_report(position)
    bridge = Farming.bridge_plan(position, :base)

    assert pool.risk_adjusted_apr == 32.0
    assert position.total_apr == 32.0
    assert compound.status == :ready
    assert risk.flags == []
    assert bridge.target_chain == :base
  end
end
