defmodule Lux.Beams.Curve.YieldOptimizerBeam do
  @moduledoc """
  A beam that optimizes yield on Curve Finance.
  It sequentially runs analysis, withdraws liquidity from a low-yield pool,
  deposits into a high-yield pool, stakes in a gauge, and claims rewards.
  """

  use Lux.Beam,
    name: "Curve Yield Optimizer",
    description: "Executes an optimized yield strategy on Curve Finance",
    input_schema: %{
      type: :object,
      properties: %{
        source_pool_address: %{type: :string},
        target_pool_address: %{type: :string},
        gauge_address: %{type: :string},
        amount_to_move: %{type: :integer}
      },
      required: ["source_pool_address", "target_pool_address", "gauge_address", "amount_to_move"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        analysis: %{type: :object},
        withdraw_tx: %{type: :object},
        deposit_tx: %{type: :object},
        stake_tx: %{type: :object},
        rewards_tx: %{type: :object}
      },
      required: ["analysis", "withdraw_tx", "deposit_tx", "stake_tx", "rewards_tx"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Curve.CurvePoolAnalysisPrism
  alias Lux.Prisms.Curve.CurvePoolPrism
  alias Lux.Prisms.Curve.CurveGaugePrism
  alias Lux.Prisms.Curve.CurveRewardsPrism

  sequence do
    step(:analyze, CurvePoolAnalysisPrism, %{
      action: "analyze",
      pool_address: [:input, :target_pool_address]
    })

    step(:withdraw, CurvePoolPrism, %{
      action: "remove_liquidity",
      pool_address: [:input, :source_pool_address],
      amount: [:input, :amount_to_move]
    })

    step(:deposit, CurvePoolPrism, %{
      action: "add_liquidity",
      pool_address: [:input, :target_pool_address],
      amounts: [[:input, :amount_to_move], 0, 0]
    })

    step(:stake, CurveGaugePrism, %{
      action: "deposit",
      gauge_address: [:input, :gauge_address],
      amount: [:input, :amount_to_move]
    })

    step(:claim_rewards, CurveRewardsPrism, %{
      action: "claim_rewards",
      gauge_address: [:input, :gauge_address]
    })

    step(:return, Lux.Prisms.NoOp, %{
      analysis: [:steps, :analyze, :result],
      withdraw_tx: [:steps, :withdraw, :result, :transaction],
      deposit_tx: [:steps, :deposit, :result, :transaction],
      stake_tx: [:steps, :stake, :result, :transaction],
      rewards_tx: [:steps, :claim_rewards, :result, :transaction]
    })
  end
end
