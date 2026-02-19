defmodule Lux.Prisms.GasOptimization.TransactionBatcherPrism do
  @moduledoc """
  A prism that optimizes gas costs by batching multiple transactions together.

  Analyzes a set of pending transactions and groups them into optimal batches
  based on gas limits, priority, interdependencies, and cost savings.

  ## Features

  - Groups compatible transactions into batches
  - Respects gas limit constraints per batch
  - Handles transaction dependencies (ordering)
  - Calculates gas savings from batching
  - Supports priority-based ordering within batches

  ## Examples

      iex> Lux.Prisms.GasOptimization.TransactionBatcherPrism.run(%{
      ...>   transactions: [
      ...>     %{id: "tx1", to: "0xabc...", gas_estimate: 21000, priority: "high"},
      ...>     %{id: "tx2", to: "0xdef...", gas_estimate: 45000, priority: "low"},
      ...>     %{id: "tx3", to: "0xabc...", gas_estimate: 35000, priority: "medium"}
      ...>   ],
      ...>   max_batch_gas: 300000
      ...> })
      {:ok, %{
        batches: [
          %{batch_id: 1, transactions: [...], total_gas: 56000, savings_pct: 8.5},
          %{batch_id: 2, transactions: [...], total_gas: 45000, savings_pct: 0.0}
        ],
        total_gas_saved: 12000,
        total_savings_pct: 5.2,
        batch_count: 2
      }}
  """

  use Lux.Prism,
    name: "Transaction Batcher",
    description: "Batches multiple transactions for gas-efficient execution",
    input_schema: %{
      type: :object,
      properties: %{
        transactions: %{
          type: :array,
          description: "List of transactions to batch",
          items: %{
            type: :object,
            properties: %{
              id: %{type: :string, description: "Unique transaction identifier"},
              to: %{type: :string, description: "Destination address"},
              data: %{type: :string, description: "Transaction calldata (hex)"},
              value: %{type: :string, description: "ETH value in wei"},
              gas_estimate: %{type: :integer, description: "Estimated gas usage"},
              priority: %{
                type: :string,
                enum: ["low", "medium", "high", "critical"],
                default: "medium"
              },
              depends_on: %{
                type: :array,
                items: %{type: :string},
                description: "IDs of transactions this depends on"
              }
            },
            required: ["id", "to", "gas_estimate"]
          }
        },
        max_batch_gas: %{
          type: :integer,
          description: "Maximum gas per batch",
          default: 500_000
        },
        strategy: %{
          type: :string,
          enum: ["gas_optimal", "priority_first", "same_target"],
          description: "Batching strategy",
          default: "gas_optimal"
        }
      },
      required: ["transactions"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        batches: %{
          type: :array,
          description: "Optimized transaction batches"
        },
        total_gas_without_batching: %{type: :integer},
        total_gas_with_batching: %{type: :integer},
        total_gas_saved: %{type: :integer},
        total_savings_pct: %{type: :number},
        batch_count: %{type: :integer}
      }
    }

  require Logger

  # Per-transaction overhead saved when batching to same contract
  @batch_overhead_savings 5_000
  # Base transaction cost
  @base_tx_cost 21_000

  def handler(input, _ctx) do
    transactions = Map.get(input, :transactions, [])
    max_batch_gas = Map.get(input, :max_batch_gas, 500_000)
    strategy = Map.get(input, :strategy, "gas_optimal")

    if Enum.empty?(transactions) do
      {:error, "No transactions provided"}
    else
      normalized = normalize_transactions(transactions)
      batches = create_batches(normalized, max_batch_gas, strategy)
      analysis = analyze_batches(batches, normalized)

      {:ok, analysis}
    end
  end

  @doc """
  Creates optimized transaction batches based on the selected strategy.
  """
  def create_batches(transactions, max_gas, strategy) do
    # First, topologically sort by dependencies
    sorted = topological_sort(transactions)

    case strategy do
      "gas_optimal" -> batch_gas_optimal(sorted, max_gas)
      "priority_first" -> batch_priority_first(sorted, max_gas)
      "same_target" -> batch_same_target(sorted, max_gas)
      _ -> batch_gas_optimal(sorted, max_gas)
    end
  end

  @doc """
  Normalizes transaction inputs to consistent format.
  """
  def normalize_transactions(transactions) do
    Enum.map(transactions, fn tx ->
      %{
        id: to_string(get_field(tx, :id, "unknown")),
        to: to_string(get_field(tx, :to, "")),
        data: to_string(get_field(tx, :data, "")),
        value: to_string(get_field(tx, :value, "0")),
        gas_estimate: get_field(tx, :gas_estimate, 21_000),
        priority: to_string(get_field(tx, :priority, "medium")),
        depends_on: get_field(tx, :depends_on, []) || []
      }
    end)
  end

  @doc """
  Topological sort respecting transaction dependencies.
  """
  def topological_sort(transactions) do
    tx_map = Map.new(transactions, &{&1.id, &1})
    {sorted, _} = do_topo_sort(transactions, tx_map, MapSet.new(), MapSet.new(), [])
    Enum.reverse(sorted)
  end

  defp do_topo_sort([], _tx_map, _visited, _in_progress, acc), do: {acc, MapSet.new()}

  defp do_topo_sort([tx | rest], tx_map, visited, in_progress, acc) do
    if MapSet.member?(visited, tx.id) do
      do_topo_sort(rest, tx_map, visited, in_progress, acc)
    else
      {new_acc, new_visited} = visit_node(tx, tx_map, visited, in_progress, acc)
      do_topo_sort(rest, tx_map, new_visited, in_progress, new_acc)
    end
  end

  defp visit_node(tx, tx_map, visited, in_progress, acc) do
    if MapSet.member?(visited, tx.id) do
      {acc, visited}
    else
      new_in_progress = MapSet.put(in_progress, tx.id)

      # Visit dependencies first
      {dep_acc, dep_visited} =
        Enum.reduce(tx.depends_on, {acc, visited}, fn dep_id, {curr_acc, curr_visited} ->
          case Map.get(tx_map, dep_id) do
            nil -> {curr_acc, curr_visited}
            dep_tx -> visit_node(dep_tx, tx_map, curr_visited, new_in_progress, curr_acc)
          end
        end)

      {[tx | dep_acc], MapSet.put(dep_visited, tx.id)}
    end
  end

  # Gas-optimal: pack transactions to maximize gas utilization per batch
  defp batch_gas_optimal(transactions, max_gas) do
    {batches, current_batch, _current_gas} =
      Enum.reduce(transactions, {[], [], 0}, fn tx, {batches, current, gas_used} ->
        if gas_used + tx.gas_estimate <= max_gas do
          {batches, [tx | current], gas_used + tx.gas_estimate}
        else
          if current == [] do
            # Single tx exceeds max, put it alone
            {[[tx] | batches], [], 0}
          else
            {[Enum.reverse(current) | batches], [tx], tx.gas_estimate}
          end
        end
      end)

    final_batches =
      if current_batch != [], do: [Enum.reverse(current_batch) | batches], else: batches

    final_batches
    |> Enum.reverse()
    |> Enum.with_index(1)
    |> Enum.map(fn {txs, idx} ->
      %{
        batch_id: idx,
        transactions: txs,
        total_gas: Enum.sum(Enum.map(txs, & &1.gas_estimate)),
        tx_count: length(txs)
      }
    end)
  end

  # Priority-first: batch by priority level, highest first
  defp batch_priority_first(transactions, max_gas) do
    priority_order = %{"critical" => 0, "high" => 1, "medium" => 2, "low" => 3}

    transactions
    |> Enum.sort_by(fn tx -> Map.get(priority_order, tx.priority, 2) end)
    |> batch_gas_optimal(max_gas)
  end

  # Same-target: group transactions to the same address
  defp batch_same_target(transactions, max_gas) do
    transactions
    |> Enum.group_by(& &1.to)
    |> Enum.flat_map(fn {_addr, txs} -> batch_gas_optimal(txs, max_gas) end)
    |> Enum.with_index(1)
    |> Enum.map(fn {batch, idx} -> %{batch | batch_id: idx} end)
  end

  @doc """
  Analyzes batching results and calculates gas savings.
  """
  def analyze_batches(batches, original_transactions) do
    total_without = Enum.sum(Enum.map(original_transactions, fn tx ->
      tx.gas_estimate + @base_tx_cost
    end))

    total_with = Enum.reduce(batches, 0, fn batch, acc ->
      batch_gas = batch.total_gas
      # Transactions to same target in a batch share base cost
      unique_targets = batch.transactions |> Enum.map(& &1.to) |> Enum.uniq() |> length()
      same_target_savings = max(0, (batch.tx_count - unique_targets) * @batch_overhead_savings)
      acc + batch_gas + @base_tx_cost - same_target_savings
    end)

    gas_saved = max(0, total_without - total_with)
    savings_pct = if total_without > 0, do: Float.round(gas_saved / total_without * 100, 1), else: 0.0

    enriched_batches = Enum.map(batches, fn batch ->
      unique_targets = batch.transactions |> Enum.map(& &1.to) |> Enum.uniq() |> length()
      batch_savings = max(0, (batch.tx_count - unique_targets) * @batch_overhead_savings)
      batch_savings_pct = if batch.total_gas > 0,
        do: Float.round(batch_savings / batch.total_gas * 100, 1),
        else: 0.0

      Map.merge(batch, %{
        unique_targets: unique_targets,
        estimated_savings: batch_savings,
        savings_pct: batch_savings_pct
      })
    end)

    %{
      batches: enriched_batches,
      total_gas_without_batching: total_without,
      total_gas_with_batching: total_with,
      total_gas_saved: gas_saved,
      total_savings_pct: savings_pct,
      batch_count: length(batches),
      total_transactions: length(original_transactions)
    }
  end

  defp get_field(map, key, default) when is_atom(key) do
    Map.get(map, key) || Map.get(map, to_string(key)) || default
  end
end
