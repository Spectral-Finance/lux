defmodule Lux.Prisms.Defi.Curve.AnalyzePoolPrism do
  @moduledoc """
  Analyzes a Curve Finance pool's virtual price, balance skew, and stability health score.
  """

  use Lux.Prism,
    name: "Analyze Curve Pool",
    description: "Evaluates Curve pool virtual price, coin imbalances, and stability health score",
    input_schema: %{
      type: :object,
      properties: %{
        pool_id: %{type: :string, description: "Curve pool ID or address", default: "3pool"},
        balances: %{type: :array, items: %{type: :number}, description: "List of pool coin balances"},
        amp: %{type: :integer, description: "Amplification coefficient A", default: 2000},
        total_lp_supply: %{type: :integer, description: "Total LP token supply", default: 1000000000}
      },
      required: ["balances"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        pool_id: %{type: :string},
        virtual_price: %{type: :number},
        imbalanced: %{type: :boolean},
        recommended_deposit_coin_index: %{type: :integer},
        health_score: %{type: :integer},
        status: %{type: :string}
      },
      required: ["pool_id", "virtual_price", "imbalanced", "health_score", "status"]
    }

  alias Lux.Defi.Curve.PoolManager
  alias Lux.Defi.Curve.Monitor

  def handler(input, _ctx) do
    pool_id = Map.get(input, :pool_id) || Map.get(input, "pool_id", "3pool")
    balances = Map.get(input, :balances) || Map.get(input, "balances", [1000, 1000, 1000])
    amp = Map.get(input, :amp) || Map.get(input, "amp", 2000)
    supply = Map.get(input, :total_lp_supply) || Map.get(input, "total_lp_supply", 1_000_000_000)

    vp = PoolManager.calculate_virtual_price(balances, amp, supply)
    analysis = PoolManager.analyze_balances(balances)
    health = Monitor.evaluate_pool_health(balances)

    {:ok,
     %{
       pool_id: pool_id,
       virtual_price: vp,
       imbalanced: analysis.imbalanced?,
       recommended_deposit_coin_index: analysis.underrepresented_index,
       health_score: health.score,
       status: to_string(health.status)
     }}
  end
end
