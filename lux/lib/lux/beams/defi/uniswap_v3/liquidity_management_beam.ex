defmodule Lux.Beams.Defi.UniswapV3.LiquidityManagementBeam do
  @moduledoc """
  Automated Uniswap V3 Liquidity Management Beam.
  Orchestrates:
  1. Position health checks and impermanent loss monitoring
  2. Rebalancing necessity evaluation
  3. Dynamic range re-centering and optimization
  """

  use Lux.Beam,
    name: "Uniswap V3 Liquidity Management Beam",
    description: "Monitors concentrated liquidity, triggers automated rebalancing, and optimizes yield ranges",
    input_schema: %{
      type: :object,
      properties: %{
        position: %{type: :object, description: "Existing Uniswap V3 position data"},
        current_tick: %{type: :integer, description: "Current pool tick"},
        fee: %{type: :integer, default: 3000},
        strategy: %{type: :string, default: "moderate"},
        entry_price: %{type: :number},
        current_price: %{type: :number},
        price_lower: %{type: :number},
        price_upper: %{type: :number}
      },
      required: ["position", "current_tick", "entry_price", "current_price", "price_lower", "price_upper"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        token_id: %{type: :string},
        in_range: %{type: :boolean},
        health_score: %{type: :integer},
        rebalance_action: %{type: :string},
        rebalance_viable: %{type: :boolean},
        optimal_tick_lower: %{type: :integer},
        optimal_tick_upper: %{type: :integer}
      },
      required: ["token_id", "in_range", "health_score", "rebalance_action"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Defi.UniswapV3.CheckPositionHealthPrism
  alias Lux.Prisms.Defi.UniswapV3.RebalancePositionPrism
  alias Lux.Prisms.Defi.UniswapV3.OptimizeRangePrism

  sequence do
    step(:health_check, CheckPositionHealthPrism, %{
      position: [:input, :position],
      current_tick: [:input, :current_tick],
      entry_price: [:input, :entry_price],
      current_price: [:input, :current_price],
      price_lower: [:input, :price_lower],
      price_upper: [:input, :price_upper]
    })

    step(:rebalance_eval, RebalancePositionPrism, %{
      position: [:input, :position],
      current_tick: [:input, :current_tick],
      strategy: [:input, :strategy]
    })

    step(:range_optimize, OptimizeRangePrism, %{
      current_tick: [:input, :current_tick],
      fee: [:input, :fee],
      strategy: [:input, :strategy]
    })

    step(:return, Lux.Prisms.NoOp, %{
      token_id: [:steps, :health_check, :result, :token_id],
      in_range: [:steps, :health_check, :result, :in_range],
      health_score: [:steps, :health_check, :result, :health_score],
      rebalance_action: [:steps, :rebalance_eval, :result, :action],
      rebalance_viable: [:steps, :rebalance_eval, :result, :viable],
      optimal_tick_lower: [:steps, :range_optimize, :result, :tick_lower],
      optimal_tick_upper: [:steps, :range_optimize, :result, :tick_upper]
    })
  end
end
