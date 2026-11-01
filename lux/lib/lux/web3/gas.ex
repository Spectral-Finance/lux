defmodule Lux.Web3.Gas do
  @moduledoc """
  Top-level coordinator for Web3 Gas Optimization and Transaction Management in Lux.

  Provides a unified interface for:
  - Base fee and priority fee prediction (`predict_fees/2`)
  - Multicall3 batch bundling (`create_batch/1`)
  - Replace-By-Fee transaction acceleration and cancellation (`speed_up/2`, `cancel/2`)
  - MEV frontrunning and sandwich protection (`protect_mev/1`)
  - Dry-run simulation and revert inspection (`simulate/2`)
  - Cost analysis and savings reporting (`analyze_cost/2`)
  - End-to-end transaction optimization pipeline (`optimize/2`)
  """

  alias Lux.Web3.Gas.{Batcher, MevGuard, Predictor, ReplacementManager, Reporter, Simulator}

  defdelegate predict_fees(tier, opts), to: Predictor
  defdelegate calculate_next_base_fee(current_base_fee, gas_used, gas_limit), to: Predictor
  defdelegate create_batch(calls), to: Batcher
  defdelegate speed_up(tx, bump_multiplier \\ 1.15), to: ReplacementManager, as: :create_speed_up
  defdelegate cancel(tx, bump_multiplier \\ 1.25), to: ReplacementManager, as: :create_cancel
  defdelegate protect_mev(params), to: MevGuard, as: :analyze_vulnerability
  defdelegate simulate(tx, opts \\ []), to: Simulator, as: :simulate_transaction
  defdelegate decode_revert(hex), to: Simulator, as: :decode_revert_reason
  defdelegate analyze_cost(params, savings \\ %{}), to: Reporter, as: :generate_report

  @doc """
  Runs an end-to-end gas optimization assessment for a transaction.
  """
  @spec optimize(map(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def optimize(tx, opts \\ []) do
    tier = Keyword.get(opts, :tier, :standard)
    history = Keyword.get(opts, :history, [])
    eth_price = Keyword.get(opts, :eth_price_usd, 2500.0)

    # 1. MEV Protection Check
    mev_report = protect_mev(tx)

    # 2. Gas Price Prediction
    fee_pred = predict_fees(tier, %{history: history})

    # 3. Simulation & Revert Check
    simulation = simulate(tx, opts)

    # 4. Cost Analysis
    cost_report =
      analyze_cost(
        %{
          gas_used: simulation.recommended_gas_limit,
          base_fee_gwei: fee_pred.base_fee_gwei,
          priority_fee_gwei: fee_pred.max_priority_fee_gwei,
          eth_price_usd: eth_price
        },
        %{
          access_list_savings: simulation.access_list_savings,
          gas_refund: simulation.gas_refund
        }
      )

    optimized_plan = %{
      status: if(simulation.success, do: :ready, else: :reverted),
      simulation: simulation,
      fee_parameters: fee_pred,
      mev_protection: mev_report,
      cost_breakdown: cost_report,
      recommended_execution: %{
        gas_limit: simulation.recommended_gas_limit,
        max_fee_per_gas: fee_pred.max_fee_wei,
        max_priority_fee_per_gas: fee_pred.max_priority_fee_wei,
        target_rpc: mev_report.private_rpc_endpoint,
        routing_mode: mev_report.recommended_route
      }
    }

    {:ok, optimized_plan}
  end
end
