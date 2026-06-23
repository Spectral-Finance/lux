defmodule Lux.Web3.Gas do
  @moduledoc """
  Gas Optimization and Transaction Management System.

  Provides a unified interface for:
  - Gas price prediction with EIP-1559 fee tiers
  - Transaction batching with nonce management
  - Transaction replacement (speed up / cancel)
  - MEV protection analysis
  - Transaction simulation
  - Cost analysis reporting
  - Gas token integration
  """

  alias Lux.Web3.Gas.{
    PricePredictor,
    TransactionBatcher,
    TransactionReplacer,
    MEVProtection,
    TransactionSimulator,
    CostAnalyzer
  }

  alias Lux.Web3.Gas.Types

  @spec predict_price(keyword()) :: {:ok, Types.fee_recommendation()} | {:error, term()}
  def predict_price(opts \ []) do
    PricePredictor.predict(Enum.into(opts, %{}))
  end

  @spec create_batch([map()], keyword()) :: {:ok, Types.BatchPlan.t()} | {:error, term()}
  def create_batch(transactions, opts \ []) do
    nonce = Keyword.fetch!(opts, :nonce)
    TransactionBatcher.create_batch(transactions, nonce_start: nonce)
  end

  @spec estimate_batch_savings(non_neg_integer(), integer()) :: float()
  def estimate_batch_savings(transaction_count, avg_gas_per_tx \ 21_000) do
    TransactionBatcher.estimate_savings(transaction_count, avg_gas_per_tx)
  end

  @spec speed_up(map(), %{max_fee_per_gas: integer(), max_priority_fee_per_gas: integer()}) ::
          {:ok, Types.Replacement.t()} | {:error, String.t()}
  def speed_up(original_tx, new_fees) do
    TransactionReplacer.speed_up(original_tx, new_fees)
  end

  @spec cancel(String.t(), integer(), integer(), integer()) ::
          {:ok, Types.Replacement.t()} | {:error, String.t()}
  def cancel(original_tx_hash, nonce, max_fee_per_gas, max_priority_fee_per_gas) do
    TransactionReplacer.cancel(original_tx_hash, nonce, max_fee_per_gas, max_priority_fee_per_gas)
  end

  @spec validate_replacement(map(), map()) :: :ok | {:error, String.t()}
  def validate_replacement(original, replacement) do
    TransactionReplacer.validate_replacement(original, replacement)
  end

  @spec analyze_mev(map()) :: {:ok, Types.MEVAnalysis.t()} | {:error, term()}
  def analyze_mev(tx) do
    MEVProtection.analyze(tx)
  end

  @spec is_dex_interaction?(String.t()) :: boolean()
  def is_dex_interaction?(address) do
    MEVProtection.is_dex_interaction?(address)
  end

  @spec simulate(map()) :: {:ok, Types.SimulationResult.t()} | {:error, term()}
  def simulate(tx) do
    TransactionSimulator.simulate(tx)
  end

  @spec preflight_check(map()) :: {:ok, map()} | {:error, String.t()}
  def preflight_check(tx) do
    TransactionSimulator.preflight_check(tx)
  end

  @spec cost_report([map()], String.t()) :: {:ok, Types.CostReport.t()} | {:error, term()}
  def cost_report(transactions, period \ "") do
    CostAnalyzer.generate_report(transactions, period)
  end

  @spec compare_costs(integer(), integer(), integer()) :: map()
  def compare_costs(gas_used, current_gas_price, optimal_gas_price) do
    CostAnalyzer.compare_costs(gas_used, current_gas_price, optimal_gas_price)
  end

  @spec gas_token_config() :: Types.GasTokenConfig.t()
  def gas_token_config do
    %Types.GasTokenConfig{
      enabled: Application.get_env(:lux, :gas_token_enabled, false),
      token_address: Application.get_env(:lux, :gas_token_address),
      token_symbol: Application.get_env(:lux, :gas_token_symbol, "GNT"),
      approval_required: true
    }
  end
end
