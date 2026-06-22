defmodule Lux.Prisms.Gas.TransactionBatchingPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Gas.TransactionBatchingPrism

  describe "handler/2 - basic functionality" do
    test "batches multiple transactions" do
      result = TransactionBatchingPrism.handler(%{
        transactions: [
          %{to: "0xd3cDA913deb6F67967B99D67aCdF1712C293601", value: "1000000000000000000"},
          %{to: "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD18", value: "500000000000000000"},
          %{to: "0x583031D1113aD414E0377633752c2A6fF3c2D8C9", value: "250000000000000000"}
        ],
        gas_price_gwei: 30
      })

      assert {:ok, plan} = result
      assert plan.total_transactions == 3
      assert is_map(plan.batch_plan)
      assert plan.batch_plan.plan |> is_list()
      assert is_integer(plan.total_gas_estimate)
      assert plan.total_gas_estimate > 0
      assert is_number(plan.total_cost_eth)
      assert plan.total_cost_eth > 0
      assert is_number(plan.individual_cost_eth)
      assert plan.individual_cost_eth > plan.total_cost_eth
      assert is_number(plan.gas_savings_percent)
      assert plan.gas_savings_percent >= 0
      assert is_map(plan.nonce_range)
    end

    test "orders transactions by nonce" do
      result = TransactionBatchingPrism.handler(%{
        transactions: [
          %{to: "0xd3cDA913deb6F67967B99D67aCdF1712C293601", value: "1000000000000000000", nonce: 5},
          %{to: "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD18", value: "500000000000000000", nonce: 3},
          %{to: "0x583031D1113aD414E0377633752c2A6fF3c2D8C9", value: "250000000000000000", nonce: 4}
        ],
        gas_price_gwei: 30
      })

      assert {:ok, plan} = result
      nonces = Enum.map(plan.batch_plan.plan, & &1.nonce)
      assert nonces == [3, 4, 5]
    end

    test "respects max batch size" do
      transactions =
        for i <- 1..20 do
          %{to: "0xd3cDA913deb6F67967B99D67aCdF1712C293601", value: "100000000000000000"}
        end

      result = TransactionBatchingPrism.handler(%{
        transactions: transactions,
        gas_price_gwei: 30,
        max_batch_size: 5
      })

      assert {:ok, plan} = result
      assert plan.total_transactions == 5
    end

    test "handles single transaction" do
      result = TransactionBatchingPrism.handler(%{
        transactions: [
          %{to: "0xd3cDA913deb6F67967B99D67aCdF1712C293601", value: "1000000000000000000"}
        ],
        gas_price_gwei: 30
      })

      assert {:ok, plan} = result
      assert plan.total_transactions == 1
    end

    test "handles contract interaction with data" do
      result = TransactionBatchingPrism.handler(%{
        transactions: [
          %{
            to: "0xd3cDA913deb6F67967B99D67aCdF1712C293601",
            value: "0",
            data: "0xa9059cbb000000000000000000000000742d35cc6634c0532925a3b844bc9e7595f2bd18"
          }
        ],
        gas_price_gwei: 30
      })

      assert {:ok, plan} = result
      assert plan.total_transactions == 1
      # Contract interaction should use higher gas estimate
      assert plan.total_gas_estimate >= 65_000
    end

    test "handles empty transactions list" do
      result = TransactionBatchingPrism.handler(%{
        transactions: [],
        gas_price_gwei: 30
      })

      assert {:error, reason} = result
      assert reason =~ "No transactions"
    end

    test "uses custom gas limit when provided" do
      result = TransactionBatchingPrism.handler(%{
        transactions: [
          %{to: "0xd3cDA913deb6F67967B99D67aCdF1712C293601", value: "0", gas_limit: 100_000}
        ],
        gas_price_gwei: 30
      })

      assert {:ok, plan} = result
      assert plan.total_gas_estimate == 100_000
    end
  end
