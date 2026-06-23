defmodule Lux.Web3.Gas.CostAnalyzer do
  @moduledoc """
  Gas cost analysis reporting.
  """

  alias Lux.Web3.Gas.Types

  @doc """
  Generates a gas cost report from a list of transaction records.
  """
  @spec generate_report([map()], period :: String.t()) :: {:ok, Types.CostReport.t()} | {:error, term()}
  def generate_report(transactions, period \ "") when is_list(transactions) and is_binary(period) do
    if Enum.empty?(transactions) do
      {:error, :empty_report}
    else
      total_gas = Enum.sum_by(transactions, &Map.get(&1, :gas_used, 0))
      total_cost_wei = Enum.sum_by(transactions, &(&1[:gas_used] || 0) * (&1[:gas_price] || 0))
      total_cost_eth = total_cost_wei / :math.pow(10, 18)
      tx_count = length(transactions)
      avg_gas_price = if total_gas > 0, do: div(total_cost_wei, total_gas), else: 0
      avg_cost_per_tx = total_cost_eth / tx_count

      estimated_standalone_cost =
        Enum.reduce(transactions, 0, fn tx, acc ->
          gas = Map.get(tx, :gas_used, 21_000)
          overhead = floor(gas * 0.15)
          acc + gas * Map.get(tx, :gas_price, 30_000_000_000) + overhead
        end)

      savings_pct =
        if estimated_standalone_cost > 0 do
          (estimated_standalone_cost - total_cost_wei) / estimated_standalone_cost * 100
        else
          0
        end

      breakdown =
        transactions
        |> Enum.group_by(fn tx -> Map.get(tx, :type, "unknown") end)
        |> Enum.map(fn {type, txns} ->
          %{
            type: type,
            count: length(txns),
            total_gas: Enum.sum_by(txns, &Map.get(&1, :gas_used, 0)),
            total_cost_eth: Enum.sum_by(txns, &(&1[:gas_used] || 0) * (&1[:gas_price] || 0)) / :math.pow(10, 18)
          }
        end)

      report = %Types.CostReport{
        period: period,
        total_transactions: tx_count,
        total_gas_used: total_gas,
        total_cost_wei: total_cost_wei,
        total_cost_eth: Float.round(total_cost_eth, 8),
        average_gas_price: avg_gas_price,
        average_cost_per_tx_eth: Float.round(avg_cost_per_tx, 8),
        savings_from_optimization: Float.round(savings_pct, 2),
        breakdown_by_type: breakdown
      }

      {:ok, report}
    end
  end

  @doc """
  Calculates the cost difference between current and optimal gas prices.
  """
  @spec compare_costs(integer(), integer(), integer()) :: %{
          current_cost_wei: integer(),
          optimal_cost_wei: integer(),
          savings_wei: integer(),
          savings_pct: float()
        }
  def compare_costs(gas_used, current_gas_price, optimal_gas_price) do
    current_cost = gas_used * current_gas_price
    optimal_cost = gas_used * optimal_gas_price
    savings = current_cost - optimal_cost
    savings_pct = if current_cost > 0, do: savings / current_cost * 100, else: 0.0

    %{
      current_cost_wei: current_cost,
      optimal_cost_wei: optimal_cost,
      savings_wei: max(savings, 0),
      savings_pct: Float.round(savings_pct, 2)
    }
  end

  defp max(a, b) when a > b, do: a
  defp max(_, b), do: b
end
