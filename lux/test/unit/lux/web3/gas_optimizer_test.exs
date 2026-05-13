defmodule Lux.Web3.GasOptimizerTest do
  use UnitAPICase, async: true

  alias Lux.Web3.GasOptimizer

  @gwei 1_000_000_000

  describe "recommend_eip1559_fee/2" do
    test "builds a normal urgency fee plan from fee samples" do
      assert {:ok, plan} =
               GasOptimizer.recommend_eip1559_fee(%{
                 base_fee_per_gas: 30 * @gwei,
                 priority_fee_samples: [1 * @gwei, 2 * @gwei, 3 * @gwei]
               })

      assert plan.base_fee_per_gas == 30 * @gwei
      assert plan.max_priority_fee_per_gas == 2 * @gwei
      assert plan.max_fee_per_gas == 39_500_000_000
      assert plan.urgency == :normal
      assert plan.strategy == :eip1559
    end

    test "supports hex RPC quantities and fast urgency" do
      assert {:ok, plan} =
               GasOptimizer.recommend_eip1559_fee(
                 %{
                   "base_fee_per_gas" => "0x3b9aca00",
                   "priority_fee_samples" => ["0x3b9aca00", "0x77359400", "0xb2d05e00"]
                 },
                 %{urgency: :fast}
               )

      assert plan.base_fee_per_gas == @gwei
      assert plan.max_priority_fee_per_gas == 3 * @gwei
      assert plan.max_fee_per_gas == 4_500_000_000
    end
  end

  describe "replacement transactions" do
    test "bumps EIP-1559 fees for speed-up transactions" do
      tx = %{
        nonce: 7,
        to: "0xrecipient",
        value: 1,
        max_fee_per_gas: 100,
        max_priority_fee_per_gas: 20
      }

      assert {:ok, replacement} = GasOptimizer.speed_up_transaction(tx, %{bump_bps: 1_250})
      assert replacement.nonce == 7
      assert replacement.max_fee_per_gas == 113
      assert replacement.max_priority_fee_per_gas == 23
    end

    test "builds cancel transactions with same nonce and bumped fees" do
      tx = %{
        nonce: 9,
        to: "0xrecipient",
        value: 100,
        data: "0x1234",
        max_fee_per_gas: 100,
        max_priority_fee_per_gas: 20
      }

      assert {:ok, cancel} = GasOptimizer.cancel_transaction(tx, "0xsender", %{bump_bps: 1_000})
      assert cancel.nonce == 9
      assert cancel.to == "0xsender"
      assert cancel.value == 0
      assert cancel.data == "0x"
      assert cancel.max_fee_per_gas == 110
      assert cancel.max_priority_fee_per_gas == 22
    end
  end

  describe "batch planning and analysis" do
    test "orders nonce transactions before priority-only transactions" do
      transactions = [
        %{id: "late", priority: 10, gas_limit: 21_000},
        %{id: "nonce-2", nonce: 2, gas_limit: 21_000},
        %{id: "nonce-1", nonce: 1, gas_limit: 21_000}
      ]

      assert GasOptimizer.plan_batch(transactions) |> Enum.map(& &1.id) == [
               "nonce-1",
               "nonce-2",
               "late"
             ]
    end

    test "calculates worst-case batch cost" do
      transactions = [
        %{id: "a", nonce: 1, gas_limit: 21_000, to: "0xa"},
        %{id: "b", nonce: 2, gas_limit: "50000", to: "0xb"}
      ]

      assert {:ok, report} =
               GasOptimizer.analyze_batch(transactions, %{max_fee_per_gas: 40 * @gwei})

      assert report.count == 2
      assert report.total_gas == 71_000
      assert report.total_max_cost_wei == 2_840_000_000_000_000
      assert Enum.map(report.transactions, & &1.id) == ["a", "b"]
    end
  end

  describe "mev_protection_plan/1" do
    test "returns conservative execution hints" do
      plan = GasOptimizer.mev_protection_plan(%{private_relay: false, max_slippage_bps: 25})

      refute plan.private_relay
      assert plan.simulate_before_send
      assert plan.enforce_deadline
      assert plan.max_slippage_bps == 25
      assert is_list(plan.notes)
    end
  end
end
