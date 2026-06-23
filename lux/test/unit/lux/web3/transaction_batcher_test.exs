defmodule Lux.Web3.Gas.TransactionBatcherTest do
  use UnitAPICase, async: true

  alias Lux.Web3.Gas.TransactionBatcher

  describe "create_batch/2" do
    test "creates a valid batch plan from transactions" do
      transactions = [
        %{nonce: 10, to: "0x1234", data: "0xabcd", gas_limit: 21_000, max_fee_per_gas: 30_000_000_000},
        %{nonce: 11, to: "0x5678", data: "0xef01", gas_limit: 50_000, max_fee_per_gas: 35_000_000_000},
        %{nonce: 12, to: "0x9abc", data: "0x2345", gas_limit: 100_000, max_fee_per_gas: 40_000_000_000}
      ]

      assert {:ok, batch} = TransactionBatcher.create_batch(transactions, nonce_start: 10)

      assert batch.id != nil
      assert batch.transactions == transactions
      assert batch.nonce_start == 10
      assert batch.estimated_total_gas == 171_000
      assert batch.estimated_total_cost_eth > 0
      assert batch.created_at != nil
    end

    test "rejects empty batch" do
      assert {:error, :empty_batch} = TransactionBatcher.create_batch([], nonce_start: 0)
    end

    test "sorts transactions by nonce" do
      unordered = [
        %{nonce: 12, to: "0xaa", data: "0xbb", gas_limit: 21_000},
        %{nonce: 10, to: "0xcc", data: "0xdd", gas_limit: 21_000},
        %{nonce: 11, to: "0xee", data: "0xff", gas_limit: 21_000}
      ]

      assert {:ok, batch} = TransactionBatcher.create_batch(unordered, nonce_start: 10)
      nonces = Enum.map(batch.transactions, & &1.nonce)
      assert nonces == [10, 11, 12]
    end
  end

  describe "estimate_savings/2" do
    test "returns positive savings percentage for multiple transactions" do
      savings = TransactionBatcher.estimate_savings(10, 21_000)
      assert savings > 0
      assert savings < 100
    end

    test "returns zero for single or zero transactions" do
      assert TransactionBatcher.estimate_savings(1, 21_000) == 0.0
      assert TransactionBatcher.estimate_savings(0, 21_000) == 0.0
    end
  end
end
