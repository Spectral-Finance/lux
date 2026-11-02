defmodule Lux.Prisms.Defi.UniswapV3.CollectAndReinvestPrism do
  @moduledoc """
  Calculates auto-compounding fee re-investment allocations and token swap routing.
  """

  use Lux.Prism,
    name: "Collect and Reinvest Uniswap V3 Fees",
    description: "Calculates auto-compounding reinvestment allocation and necessary re-balancing swaps",
    input_schema: %{
      type: :object,
      properties: %{
        collected0: %{type: :integer, description: "Collected token0 fees", default: 0},
        collected1: %{type: :integer, description: "Collected token1 fees", default: 0},
        target_ratio: %{type: :number, description: "Target deposit ratio (amount0 / amount1)", default: 1.0},
        price0_usd: %{type: :number, default: 1.0},
        price1_usd: %{type: :number, default: 1.0}
      },
      required: ["collected0", "collected1"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        reinvest0: %{type: :integer},
        reinvest1: %{type: :integer},
        swap_required: %{type: :boolean},
        swap_direction: %{type: :string},
        swap_amount: %{type: :integer}
      },
      required: ["reinvest0", "reinvest1", "swap_required", "swap_direction"]
    }

  alias Lux.Defi.UniswapV3.YieldOptimizer

  def handler(input, _ctx) do
    collected0 = Map.get(input, :collected0) || Map.get(input, "collected0", 0)
    collected1 = Map.get(input, :collected1) || Map.get(input, "collected1", 0)
    target_ratio = Map.get(input, :target_ratio) || Map.get(input, "target_ratio", 1.0)
    price0_usd = Map.get(input, :price0_usd) || Map.get(input, "price0_usd", 1.0)
    price1_usd = Map.get(input, :price1_usd) || Map.get(input, "price1_usd", 1.0)

    result = YieldOptimizer.plan_reinvestment(collected0, collected1, target_ratio, price0_usd, price1_usd)

    {:ok,
     %{
       reinvest0: result.reinvest0,
       reinvest1: result.reinvest1,
       swap_required: result.swap_required,
       swap_direction: to_string(result.swap_direction),
       swap_amount: result.swap_amount
     }}
  end
end
