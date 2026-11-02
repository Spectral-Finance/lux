defmodule Lux.Beams.Defi.Curve.StablecoinManagementBeam do
  @moduledoc """
  Automated Curve Stablecoin Management Beam.
  Orchestrates:
  1. Curve pool health and virtual price analysis
  2. Imbalance detection and positive-slippage deposit evaluation
  3. veCRV gauge boost calculation
  4. Auto-compounding reinvestment planning
  """

  use Lux.Beam,
    name: "Curve Stablecoin Management Beam",
    description: "Orchestrates Curve pool analysis, imbalance rebalancing, gauge boost, and yield compounding",
    input_schema: %{
      type: :object,
      properties: %{
        pool_id: %{type: :string, default: "3pool"},
        balances: %{type: :array, items: %{type: :number}, description: "Coin balances in pool"},
        amp: %{type: :integer, default: 2000},
        user_lp: %{type: :number, default: 10000.0},
        total_gauge_lp: %{type: :number, default: 50000000.0},
        user_vecrv: %{type: :number, default: 0.0},
        unclaimed_crv: %{type: :number, default: 0.0}
      },
      required: ["balances"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        pool_id: %{type: :string},
        virtual_price: %{type: :number},
        pool_health_score: %{type: :integer},
        imbalanced: %{type: :boolean},
        recommended_action: %{type: :string},
        gauge_boost: %{type: :number},
        compound_viable: %{type: :boolean}
      },
      required: ["pool_id", "virtual_price", "pool_health_score", "gauge_boost"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Defi.Curve.AnalyzePoolPrism
  alias Lux.Prisms.Defi.Curve.RebalanceStablePoolPrism
  alias Lux.Prisms.Defi.Curve.CheckGaugeBoostPrism
  alias Lux.Prisms.Defi.Curve.ClaimAndCompoundPrism

  sequence do
    step(:pool_analysis, AnalyzePoolPrism, %{
      pool_id: [:input, :pool_id],
      balances: [:input, :balances],
      amp: [:input, :amp]
    })

    step(:rebalance_check, RebalanceStablePoolPrism, %{
      balances: [:input, :balances]
    })

    step(:boost_check, CheckGaugeBoostPrism, %{
      user_lp: [:input, :user_lp],
      total_gauge_lp: [:input, :total_gauge_lp],
      user_vecrv: [:input, :user_vecrv]
    })

    step(:compound_plan, ClaimAndCompoundPrism, %{
      unclaimed_crv: [:input, :unclaimed_crv]
    })

    step(:return, Lux.Prisms.NoOp, %{
      pool_id: [:steps, :pool_analysis, :result, :pool_id],
      virtual_price: [:steps, :pool_analysis, :result, :virtual_price],
      pool_health_score: [:steps, :pool_analysis, :result, :health_score],
      imbalanced: [:steps, :rebalance_check, :result, :imbalanced],
      recommended_action: [:steps, :rebalance_check, :result, :recommended_action],
      gauge_boost: [:steps, :boost_check, :result, :boost],
      compound_viable: [:steps, :compound_plan, :result, :viable]
    })
  end
end
