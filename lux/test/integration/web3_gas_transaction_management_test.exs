defmodule Lux.Integration.Web3GasTransactionManagementTest do
  use IntegrationCase, async: true

  alias Lux.Web3.GasTransactionManager

  test "builds an end-to-end gas optimization plan without broadcasting" do
    transactions = [
      %{
        id: "swap-1",
        from: "0x1111111111111111111111111111111111111111",
        to: "0x3333333333333333333333333333333333333333",
        nonce: 10,
        gas_limit: 120_000,
        value_wei: 0,
        data: "0xabcdef",
        batch_contract: "0x4444444444444444444444444444444444444444",
        priority: 2
      },
      %{
        id: "swap-2",
        from: "0x1111111111111111111111111111111111111111",
        to: "0x5555555555555555555555555555555555555555",
        nonce: 11,
        gas_limit: 130_000,
        value_wei: 0,
        data: "0x123456",
        batch_contract: "0x4444444444444444444444444444444444444444",
        priority: 1
      }
    ]

    assert {:ok, plan} =
             GasTransactionManager.management_plan(%{
               observations: %{
                 base_fee_per_gas: "25 gwei",
                 priority_fee_per_gas: "1.5 gwei",
                 gas_used_ratio: 0.82
               },
               urgency: :fast,
               account_balance_wei: 100_000_000_000_000_000,
               transactions: transactions,
               mev: %{risk: :high, relays: ["flashbots"], slippage_bps: 40},
               baseline_fee_per_gas: "80 gwei"
             })

    assert plan.ready
    assert plan.gas.selected_tier == :fast
    assert plan.batching.batch_count == 1
    assert hd(plan.batching.batches).execution_mode == :multicall
    assert plan.mev_protection.route == :private_relay
    assert plan.gas_token_strategy.status == :funded
    assert Enum.all?(plan.simulations, &(&1.status == :ok))
    assert plan.cost_report.totals.savings_wei > 0
  end
end
