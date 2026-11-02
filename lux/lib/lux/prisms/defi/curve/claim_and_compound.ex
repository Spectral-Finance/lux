defmodule Lux.Prisms.Defi.Curve.ClaimAndCompoundPrism do
  @moduledoc """
  Calculates CRV harvest yield, swap viability, and auto-compounding reinvestment plans.
  """

  use Lux.Prism,
    name: "Claim and Compound Curve Rewards",
    description: "Evaluates accrued CRV rewards and plans auto-compounding harvest swaps",
    input_schema: %{
      type: :object,
      properties: %{
        unclaimed_crv: %{type: :number, description: "Amount of unclaimed CRV accrued"},
        crv_price_usd: %{type: :number, description: "Current USD market price of CRV token", default: 0.50},
        target_coin: %{type: :string, description: "Target coin to re-invest into", default: "USDC"}
      },
      required: ["unclaimed_crv"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        crv_amount: %{type: :number},
        target_coin: %{type: :string},
        estimated_lp_return: %{type: :number},
        viable: %{type: :boolean}
      },
      required: ["crv_amount", "target_coin", "viable"]
    }

  alias Lux.Defi.Curve.YieldOptimizer

  def handler(input, _ctx) do
    unclaimed = Map.get(input, :unclaimed_crv) || Map.get(input, "unclaimed_crv", 0.0)
    price = Map.get(input, :crv_price_usd) || Map.get(input, "crv_price_usd", 0.50)
    target = Map.get(input, :target_coin) || Map.get(input, "target_coin", "USDC")

    result = YieldOptimizer.plan_autocompound(unclaimed, price, target)

    {:ok,
     %{
       crv_amount: result.crv_amount,
       target_coin: result.target_coin,
       estimated_lp_return: result.estimated_lp_return,
       viable: result.viable?
     }}
  end
end
