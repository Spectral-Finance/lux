defmodule Lux.Web3.Gas.TransactionBatcher do
  @moduledoc """
  Transaction batching with nonce-aware ordering.
  """

  alias Lux.Web3.Gas.Types
  alias Lux.UUID

  @doc """
  Creates a batch plan from a list of transaction maps.
  """
  @spec create_batch([map()], nonce_start: integer()) :: {:ok, Types.BatchPlan.t()} | {:error, term()}
  def create_batch(transactions, nonce_start: nonce) when is_list(transactions) and is_integer(nonce) do
    if Enum.empty?(transactions) do
      {:error, :empty_batch}
    else
      ordered = Enum.sort_by(transactions, fn tx -> Map.get(tx, :nonce, nonce) end)

      total_gas =
        ordered
        |> Enum.reduce(0, fn tx, acc ->
          acc + Map.get(tx, :gas_limit, 21_000)
        end)

      max_fee =
        ordered
        |> Enum.reduce(0, fn tx, acc ->
          fee = Map.get(tx, :max_fee_per_gas, 30_000_000_000)
          if fee > acc, do: fee, else: acc
        end)

      estimated_cost_eth = (total_gas * max_fee) / :math.pow(10, 18)

      batch_plan = %Types.BatchPlan{
        id: UUID.generate(),
        transactions: ordered,
        nonce_start: nonce,
        estimated_total_gas: total_gas,
        estimated_total_cost_eth: Float.round(estimated_cost_eth, 8),
        created_at: DateTime.utc_now()
      }

      {:ok, batch_plan}
    end
  end

  @doc """
  Estimates the gas savings from batching N individual transactions.
  """
  @spec estimate_savings(non_neg_integer(), integer()) :: float()
  def estimate_savings(transaction_count, avg_gas_per_tx \ 21_000)
      when is_integer(transaction_count) and transaction_count >= 0 do
    standalone_cost = transaction_count * avg_gas_per_tx
    batched_overhead = transaction_count * floor(avg_gas_per_tx * 0.85)
    (standalone_cost - batched_overhead) / standalone_cost * 100
  end
end
