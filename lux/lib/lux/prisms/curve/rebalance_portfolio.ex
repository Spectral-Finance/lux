defmodule Lux.Prisms.Curve.RebalancePortfolio do
  @moduledoc """
  A prism for automated portfolio rebalancing and yield maximization across Curve stablecoin pools,
  evaluating expected slippage against projected APY improvements.
  """

  use Lux.Prism,
    name: "Curve Rebalance Portfolio",
    description: "Evaluates and executes yield-maximizing rebalances across Curve stablecoin pools",
    input_schema: %{
      type: :object,
      properties: %{
        source_pool_id: %{type: :string, description: "Current allocated pool identifier"},
        target_pool_id: %{type: :string, description: "Candidate pool identifier with higher yield"},
        amount_usd: %{type: :number, description: "Capital amount to rebalance in USD"},
        max_allowed_slippage_bps: %{type: :integer, description: "Maximum allowed slippage in basis points", default: 20},
        min_apy_delta_pct: %{type: :number, description: "Minimum annualized yield difference required to rebalance", default: 1.5}
      },
      required: ["source_pool_id", "target_pool_id", "amount_usd"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        rebalance_recommended: %{type: :boolean},
        source_pool: %{type: :string},
        target_pool: %{type: :string},
        estimated_slippage_bps: %{type: :integer},
        apy_gain_pct: %{type: :number},
        payback_days: %{type: :number},
        execution_plan: %{type: :object}
      },
      required: ["rebalance_recommended", "source_pool", "target_pool"]
    }

  require Logger

  def handler(params, agent) do
    src = Map.get(params, :source_pool_id)
    tgt = Map.get(params, :target_pool_id)
    amount = Map.get(params, :amount_usd)
    max_slippage = Map.get(params, :max_allowed_slippage_bps, 20)
    min_apy_delta = Map.get(params, :min_apy_delta_pct, 1.5)
    agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Agent"

    Logger.info("Agent #{agent_name} calculating rebalance from #{src} to #{tgt} for $#{amount}")

    # Simulated APYs
    src_apy = if src == "3pool", do: 5.25, else: 4.50
    tgt_apy = if tgt == "crvusd-usdc", do: 11.00, else: 7.50

    apy_gain = Float.round(tgt_apy - src_apy, 2)
    estimated_slippage = 6  # 6 basis points = 0.06%

    slippage_cost_usd = amount * (estimated_slippage / 10_000.0)
    annual_gain_usd = amount * (apy_gain / 100.0)
    payback_days = if annual_gain_usd > 0, do: Float.round((slippage_cost_usd / (annual_gain_usd / 365.0)), 1), else: 999.0

    should_rebalance =
      apy_gain >= min_apy_delta and
      estimated_slippage <= max_slippage and
      payback_days <= 30.0

    {:ok, %{
      rebalance_recommended: should_rebalance,
      source_pool: src,
      target_pool: tgt,
      estimated_slippage_bps: estimated_slippage,
      apy_gain_pct: apy_gain,
      payback_days: payback_days,
      execution_plan: %{
        "step_1" => "Withdraw from #{src} as 3CRV/underlying",
        "step_2" => "Deposit to #{tgt} with minimum guarantee",
        "step_3" => "Stake minted LP tokens into target gauge",
        "estimated_gas_cost_usd" => 7.20
      }
    }}
  end
end
