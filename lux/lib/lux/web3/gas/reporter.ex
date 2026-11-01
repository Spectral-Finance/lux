defmodule Lux.Web3.Gas.Reporter do
  @moduledoc """
  Transaction cost analysis and optimization reporting engine.

  Provides:
  - Granular cost breakdowns across base fee and priority fee
  - Multi-denomination cost rendering (Wei, Gwei, ETH, USD)
  - ROI & net savings analytics for batching, access lists, and timing optimization
  """

  @wei_per_eth 1_000_000_000_000_000_000
  @wei_per_gwei 1_000_000_000

  @type cost_report :: %{
          gas_used: non_neg_integer(),
          effective_gas_price_gwei: float(),
          base_fee_gwei: float(),
          priority_fee_gwei: float(),
          total_cost_wei: non_neg_integer(),
          total_cost_gwei: float(),
          total_cost_eth: float(),
          total_cost_usd: float(),
          base_fee_cost_usd: float(),
          priority_fee_cost_usd: float(),
          savings_summary: map()
        }

  @doc """
  Generates a detailed cost breakdown and optimization report.

  ## Parameters:
    - `params`: map containing `:gas_used`, `:base_fee_gwei`, `:priority_fee_gwei`, and optional `:eth_price_usd`
    - `savings`: optional map containing `:gas_saved_batching`, `:access_list_savings`, `:gas_refund`
  """
  @spec generate_report(map(), map()) :: cost_report()
  def generate_report(params, savings \\ %{}) do
    gas_used = Map.get(params, :gas_used, 21_000)
    base_fee_gwei = Map.get(params, :base_fee_gwei, 25.0) * 1.0
    priority_fee_gwei = Map.get(params, :priority_fee_gwei, 2.0) * 1.0
    eth_price_usd = Map.get(params, :eth_price_usd, 2500.0) * 1.0

    effective_price_gwei = base_fee_gwei + priority_fee_gwei
    total_cost_gwei = gas_used * effective_price_gwei
    total_cost_wei = round(total_cost_gwei * @wei_per_gwei)
    total_cost_eth = total_cost_wei / @wei_per_eth
    total_cost_usd = Float.round(total_cost_eth * eth_price_usd, 4)

    base_fee_cost_usd = Float.round((gas_used * base_fee_gwei * @wei_per_gwei / @wei_per_eth) * eth_price_usd, 4)
    priority_fee_cost_usd = Float.round((gas_used * priority_fee_gwei * @wei_per_gwei / @wei_per_eth) * eth_price_usd, 4)

    batch_savings_gas = Map.get(savings, :gas_saved_batching, 0)
    al_savings_gas = Map.get(savings, :access_list_savings, 0)
    refund_gas = Map.get(savings, :gas_refund, 0)
    total_saved_gas = batch_savings_gas + al_savings_gas + refund_gas

    saved_usd = Float.round((total_saved_gas * effective_price_gwei * @wei_per_gwei / @wei_per_eth) * eth_price_usd, 4)

    savings_summary = %{
      total_gas_saved: total_saved_gas,
      total_usd_saved: saved_usd,
      batch_savings_gas: batch_savings_gas,
      access_list_savings_gas: al_savings_gas,
      gas_refund: refund_gas
    }

    %{
      gas_used: gas_used,
      effective_gas_price_gwei: Float.round(effective_price_gwei, 2),
      base_fee_gwei: Float.round(base_fee_gwei, 2),
      priority_fee_gwei: Float.round(priority_fee_gwei, 2),
      total_cost_wei: total_cost_wei,
      total_cost_gwei: Float.round(total_cost_gwei, 2),
      total_cost_eth: Float.round(total_cost_eth, 6),
      total_cost_usd: total_cost_usd,
      base_fee_cost_usd: base_fee_cost_usd,
      priority_fee_cost_usd: priority_fee_cost_usd,
      savings_summary: savings_summary
    }
  end

  @doc """
  Formats the report into a markdown summary table.
  """
  @spec to_markdown(cost_report()) :: String.t()
  def to_markdown(report) do
    """
    ### ⛽ Gas Cost & Optimization Report

    | Metric | Value |
    | :--- | :--- |
    | **Gas Consumed** | `#{report.gas_used}` units |
    | **Effective Gas Price** | `#{report.effective_gas_price_gwei}` Gwei |
    | **Base Fee / Priority Fee** | `#{report.base_fee_gwei}` Gwei / `#{report.priority_fee_gwei}` Gwei |
    | **Total Cost (USD)** | **$#{report.total_cost_usd}** |
    | **Total Cost (ETH)** | `#{report.total_cost_eth} ETH` |
    | **Total Gas Saved** | `#{report.savings_summary.total_gas_saved}` units (~$#{report.savings_summary.total_usd_saved}) |
    """
  end
end
