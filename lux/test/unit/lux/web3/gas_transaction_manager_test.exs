defmodule Lux.Web3.GasTransactionManagerTest do
  use UnitCase, async: true

  alias Lux.Web3.GasTransactionManager

  @base_fee 30_000_000_000
  @priority_fee 2_000_000_000
  @sender "0x1111111111111111111111111111111111111111"
  @receiver "0x2222222222222222222222222222222222222222"

  describe "predict_gas/1" do
    test "builds EIP-1559 fee tiers from wei, gwei, and hex observations" do
      assert {:ok, plan} =
               GasTransactionManager.predict_gas(%{
                 observations: %{
                   base_fee_per_gas: "0x6fc23ac00",
                   priority_fee_per_gas: "2 gwei",
                   gas_used_ratio: "0.81,0.90"
                 },
                 history: [
                   %{base_fee_per_gas: @base_fee, priority_fee_per_gas: @priority_fee},
                   %{base_fee_per_gas: 32_000_000_000, priority_fee_per_gas: "2.5 gwei"}
                 ],
                 urgency: :fast
               })

      assert plan.congestion.level == :high
      assert plan.selected_tier == :fast
      assert plan.tiers.fast.max_fee_per_gas > plan.tiers.standard.max_fee_per_gas
      assert plan.selected.max_priority_fee_per_gas == 3_125_000_000
    end
  end

  describe "batch_transactions/2" do
    test "orders transactions and groups compatible multicall batches" do
      txs = [
        tx(%{id: "late", nonce: 8, priority: 1, batch_contract: "0xbatch"}),
        tx(%{id: "early", nonce: 7, priority: 3, batch_contract: "0xbatch"}),
        tx(%{id: "other", from: @receiver, nonce: 1})
      ]

      assert {:ok, plan} =
               GasTransactionManager.batch_transactions(txs, %{max_fee_per_gas: @base_fee})

      assert plan.transaction_count == 3
      assert plan.batch_count == 2

      [first_batch, second_batch] = plan.batches
      assert first_batch.execution_mode == :multicall
      assert Enum.map(first_batch.transactions, & &1.id) == ["early", "late"]
      assert first_batch.gas_saved == 10_000
      assert second_batch.execution_mode == :sequential
    end
  end

  describe "replacement_transaction/1" do
    test "speed-up keeps nonce and bumps EIP-1559 fees" do
      assert {:ok, plan} =
               GasTransactionManager.replacement_transaction(%{
                 action: :speed_up,
                 bump_percent: 15,
                 transaction:
                   tx(%{
                     nonce: 12,
                     max_fee_per_gas: @base_fee,
                     max_priority_fee_per_gas: @priority_fee
                   })
               })

      assert plan.replacement.nonce == 12
      assert plan.replacement.to == @receiver
      assert plan.replacement.max_fee_per_gas == 34_500_000_000
      assert plan.replacement.max_priority_fee_per_gas == 2_300_000_000
    end

    test "cancel replacement zeroes value and sends to self" do
      assert {:ok, plan} =
               GasTransactionManager.replacement_transaction(%{
                 action: :cancel,
                 transaction:
                   tx(%{
                     nonce: 12,
                     value_wei: 1_000,
                     data: "0xabcdef",
                     max_fee_per_gas: @base_fee,
                     max_priority_fee_per_gas: @priority_fee
                   })
               })

      assert plan.replacement.to == @sender
      assert plan.replacement.value_wei == 0
      assert plan.replacement.data == "0x"
      assert plan.replacement.gas_limit == 21_000
    end
  end

  describe "simulation, MEV, gas token, and cost reports" do
    test "simulates balance and nonce safety" do
      assert {:ok, simulation} =
               GasTransactionManager.simulate_transaction(%{
                 transaction: tx(%{nonce: 2, max_fee_per_gas: @base_fee}),
                 account_balance_wei: 1_000,
                 pending_nonce: 3
               })

      assert simulation.status == :blocked
      assert :insufficient_balance in simulation.errors
      assert :nonce_too_low in simulation.errors
    end

    test "builds private MEV routing for high risk swaps" do
      assert {:ok, mev} =
               GasTransactionManager.mev_protection_plan(%{
                 risk: :high,
                 slippage_bps: 75,
                 relays: ["flashbots"]
               })

      assert mev.route == :private_relay
      refute mev.public_mempool_allowed
      assert mev.simulation_required
      assert mev.relays == ["flashbots"]
    end

    test "plans native gas reserve and paymaster mode" do
      assert {:ok, strategy} =
               GasTransactionManager.gas_token_strategy(%{
                 native_balance_wei: 50,
                 planned_max_fee_wei: 100,
                 buffer_percent: 25,
                 paymaster: "0xpaymaster"
               })

      assert strategy.status == :top_up_required
      assert strategy.required_native_reserve_wei == 125
      assert strategy.top_up_wei == 75
      assert strategy.gas_token_mode == :account_abstraction_paymaster
    end

    test "reports expected, maximum, and saved fees" do
      assert {:ok, report} =
               GasTransactionManager.cost_report(%{
                 transactions: [
                   tx(%{id: "a", gas_limit: 30_000}),
                   tx(%{id: "b", gas_limit: 40_000})
                 ],
                 fee_plan: %{
                   selected_tier: :standard,
                   selected: %{
                     expected_fee_per_gas: 20,
                     max_fee_per_gas: 30
                   }
                 },
                 baseline_fee_per_gas: 50
               })

      assert report.transaction_count == 2
      assert report.totals.expected_fee_wei == 1_400_000
      assert report.totals.max_fee_wei == 2_100_000
      assert report.totals.savings_wei == 2_100_000
    end
  end

  defp tx(overrides) do
    Map.merge(
      %{
        from: @sender,
        to: @receiver,
        nonce: 1,
        value_wei: 0,
        data: "0x",
        gas_limit: 21_000,
        max_fee_per_gas: @base_fee,
        max_priority_fee_per_gas: @priority_fee,
        chain_id: 1
      },
      overrides
    )
  end
end
