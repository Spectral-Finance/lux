defmodule Lux.Prisms.Defi.UniswapV3.OptimizeRangePrism do
  @moduledoc """
  Calculates optimal price bounds and tick ranges for Uniswap V3 concentrated liquidity.
  """

  use Lux.Prism,
    name: "Optimize Uniswap V3 Range",
    description: "Calculates optimal lower/upper ticks and capital efficiency for liquidity provisioning",
    input_schema: %{
      type: :object,
      properties: %{
        current_tick: %{type: :integer, description: "Current pool tick"},
        fee: %{type: :integer, enum: [100, 500, 3000, 10000], default: 3000},
        strategy: %{type: :string, enum: ["narrow", "moderate", "wide", "bullish", "bearish"], default: "moderate"},
        decimals0: %{type: :integer, default: 18},
        decimals1: %{type: :integer, default: 18}
      },
      required: ["current_tick"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        tick_lower: %{type: :integer},
        tick_upper: %{type: :integer},
        price_lower: %{type: :number},
        price_upper: %{type: :number},
        efficiency: %{type: :number}
      },
      required: ["tick_lower", "tick_upper", "price_lower", "price_upper", "efficiency"]
    }

  alias Lux.Defi.UniswapV3.RangeOptimizer

  def handler(input, _ctx) do
    current_tick = Map.get(input, :current_tick) || Map.get(input, "current_tick")
    fee = Map.get(input, :fee) || Map.get(input, "fee", 3000)
    raw_strategy = Map.get(input, :strategy) || Map.get(input, "strategy", "moderate")
    decimals0 = Map.get(input, :decimals0) || Map.get(input, "decimals0", 18)
    decimals1 = Map.get(input, :decimals1) || Map.get(input, "decimals1", 18)

    strategy =
      if is_binary(raw_strategy), do: String.to_atom(raw_strategy), else: raw_strategy

    opts = [decimals0: decimals0, decimals1: decimals1]

    case RangeOptimizer.calculate_range(current_tick, fee, strategy, opts) do
      {:ok, range} ->
        {:ok,
         %{
           tick_lower: range.tick_lower,
           tick_upper: range.tick_upper,
           price_lower: range.price_lower,
           price_upper: range.price_upper,
           efficiency: range.efficiency
         }}

      {:error, reason} ->
        {:error, "Range optimization failed: #{inspect(reason)}"}
    end
  end
end
