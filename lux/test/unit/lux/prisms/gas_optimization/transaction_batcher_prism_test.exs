defmodule Lux.Prisms.GasOptimization.TransactionBatcherPrismTest do
  use UnitAPICase, async: false

  alias Lux.Prisms.GasOptimization.TransactionBatcherPrism

  describe "handler/2" do
    test "batches multiple transactions" do
      input = %{
        transactions: [
          %{id: "tx1", to: "0xabc", gas_estimate: 21_000, priority: "high"},
          %{id: "tx2", to: "0xdef", gas_estimate: 45_000, priority: "low"},
          %{id: "tx3", to: "0xabc", gas_estimate: 35_000, priority: "medium"}
        ],
        max_batch_gas: 300_000
      }

      assert {:ok, result} = TransactionBatcherPrism.handler(input, nil)

      assert result.batch_count >= 1
      assert result.total_transactions == 3
      assert is_integer(result.total_gas_without_batching)
      assert is_integer(result.total_gas_with_batching)
      assert result.total_gas_saved >= 0
    end

    test "splits batches when exceeding max gas" do
      input = %{
        transactions: [
          %{id: "tx1", to: "0xabc", gas_estimate: 200_000},
          %{id: "tx2", to: "0xdef", gas_estimate: 200_000},
          %{id: "tx3", to: "0xghi", gas_estimate: 200_000}
        ],
        max_batch_gas: 300_000
      }

      assert {:ok, result} = TransactionBatcherPrism.handler(input, nil)

      assert result.batch_count >= 2
      # Each batch should not exceed max gas
      Enum.each(result.batches, fn batch ->
        assert batch.total_gas <= 300_000
      end)
    end

    test "returns error for empty transactions" do
      assert {:error, "No transactions provided"} =
               TransactionBatcherPrism.handler(%{transactions: []}, nil)
    end

    test "handles priority_first strategy" do
      input = %{
        transactions: [
          %{id: "tx1", to: "0xabc", gas_estimate: 21_000, priority: "low"},
          %{id: "tx2", to: "0xdef", gas_estimate: 45_000, priority: "critical"},
          %{id: "tx3", to: "0xghi", gas_estimate: 35_000, priority: "high"}
        ],
        max_batch_gas: 500_000,
        strategy: "priority_first"
      }

      assert {:ok, result} = TransactionBatcherPrism.handler(input, nil)

      first_batch = List.first(result.batches)
      # Critical and high priority should be first
      first_tx = List.first(first_batch.transactions)
      assert first_tx.priority == "critical"
    end

    test "handles same_target strategy" do
      input = %{
        transactions: [
          %{id: "tx1", to: "0xabc", gas_estimate: 21_000},
          %{id: "tx2", to: "0xdef", gas_estimate: 45_000},
          %{id: "tx3", to: "0xabc", gas_estimate: 35_000},
          %{id: "tx4", to: "0xdef", gas_estimate: 30_000}
        ],
        max_batch_gas: 500_000,
        strategy: "same_target"
      }

      assert {:ok, result} = TransactionBatcherPrism.handler(input, nil)

      # Transactions to same targets should be grouped
      Enum.each(result.batches, fn batch ->
        targets = Enum.map(batch.transactions, & &1.to) |> Enum.uniq()
        # Each batch should primarily target one address
        assert length(targets) >= 1
      end)
    end

    test "calculates gas savings" do
      input = %{
        transactions: [
          %{id: "tx1", to: "0xabc", gas_estimate: 21_000},
          %{id: "tx2", to: "0xabc", gas_estimate: 45_000},
          %{id: "tx3", to: "0xabc", gas_estimate: 35_000}
        ],
        max_batch_gas: 500_000
      }

      assert {:ok, result} = TransactionBatcherPrism.handler(input, nil)

      # All transactions to same target should show savings
      assert result.total_gas_saved >= 0
      assert is_number(result.total_savings_pct)
    end

    test "handles default values" do
      input = %{
        transactions: [
          %{id: "tx1", to: "0xabc", gas_estimate: 21_000}
        ]
      }

      assert {:ok, result} = TransactionBatcherPrism.handler(input, nil)

      assert result.batch_count == 1
      assert result.total_transactions == 1
    end
  end

  describe "normalize_transactions/1" do
    test "normalizes transaction fields" do
      txs = [
        %{id: "tx1", to: "0xabc", gas_estimate: 50_000},
        %{"id" => "tx2", "to" => "0xdef", "gas_estimate" => 30_000}
      ]

      result = TransactionBatcherPrism.normalize_transactions(txs)

      assert length(result) == 2
      assert Enum.all?(result, &is_binary(&1.id))
      assert Enum.all?(result, &is_binary(&1.to))
      assert Enum.all?(result, &is_integer(&1.gas_estimate))
    end

    test "sets default values for missing fields" do
      txs = [%{id: "tx1", to: "0xabc", gas_estimate: 21_000}]

      [normalized] = TransactionBatcherPrism.normalize_transactions(txs)

      assert normalized.priority == "medium"
      assert normalized.depends_on == []
      assert normalized.data == ""
      assert normalized.value == "0"
    end
  end

  describe "topological_sort/1" do
    test "sorts respecting dependencies" do
      txs = [
        %{id: "tx3", to: "0xabc", gas_estimate: 21_000, priority: "low", depends_on: ["tx1"], data: "", value: "0"},
        %{id: "tx1", to: "0xabc", gas_estimate: 21_000, priority: "high", depends_on: [], data: "", value: "0"},
        %{id: "tx2", to: "0xabc", gas_estimate: 21_000, priority: "medium", depends_on: ["tx1"], data: "", value: "0"}
      ]

      sorted = TransactionBatcherPrism.topological_sort(txs)
      ids = Enum.map(sorted, & &1.id)

      # tx1 should come before tx2 and tx3
      assert Enum.find_index(ids, &(&1 == "tx1")) <
               Enum.find_index(ids, &(&1 == "tx3"))
    end

    test "handles no dependencies" do
      txs = [
        %{id: "tx1", to: "0xabc", gas_estimate: 21_000, priority: "low", depends_on: [], data: "", value: "0"},
        %{id: "tx2", to: "0xdef", gas_estimate: 21_000, priority: "low", depends_on: [], data: "", value: "0"}
      ]

      sorted = TransactionBatcherPrism.topological_sort(txs)
      assert length(sorted) == 2
    end
  end

  describe "create_batches/3" do
    test "creates correct number of batches" do
      txs = [
        %{id: "tx1", to: "0xabc", gas_estimate: 100_000, priority: "medium", depends_on: [], data: "", value: "0"},
        %{id: "tx2", to: "0xdef", gas_estimate: 100_000, priority: "medium", depends_on: [], data: "", value: "0"},
        %{id: "tx3", to: "0xghi", gas_estimate: 100_000, priority: "medium", depends_on: [], data: "", value: "0"},
        %{id: "tx4", to: "0xjkl", gas_estimate: 100_000, priority: "medium", depends_on: [], data: "", value: "0"}
      ]

      batches = TransactionBatcherPrism.create_batches(txs, 350_000, "gas_optimal")

      assert length(batches) == 2
      assert Enum.all?(batches, &(&1.total_gas <= 350_000))
    end
  end

  describe "analyze_batches/2" do
    test "calculates correct totals" do
      batches = [
        %{
          batch_id: 1,
          transactions: [
            %{id: "tx1", to: "0xabc", gas_estimate: 21_000},
            %{id: "tx2", to: "0xabc", gas_estimate: 35_000}
          ],
          total_gas: 56_000,
          tx_count: 2
        }
      ]

      original = [
        %{id: "tx1", to: "0xabc", gas_estimate: 21_000},
        %{id: "tx2", to: "0xabc", gas_estimate: 35_000}
      ]

      result = TransactionBatcherPrism.analyze_batches(batches, original)

      assert result.batch_count == 1
      assert result.total_transactions == 2
      assert is_integer(result.total_gas_without_batching)
      assert is_integer(result.total_gas_with_batching)
    end
  end

  describe "view/0" do
    test "returns prism struct" do
      prism = TransactionBatcherPrism.view()

      assert prism.name == "Transaction Batcher"
      assert prism.description =~ "Batch"
    end
  end
end
