defmodule Lux.Prisms.UniswapV3.FeeCollectorPrism do
  @moduledoc """
  A prism that calculates accrued Uniswap V3 swap fees, evaluates gas-adjusted
  harvest profitability, and computes optimal token0/token1 compounding splits.
  """

  use Lux.Prism,
    name: "Uniswap V3 Fee Collector",
    description: "Evaluates and compounds accrued Uniswap V3 LP fees when net gas-profitable",
    input_schema: %{
      type: :object,
      properties: %{
        tokens_owed0: %{type: :number},
        tokens_owed1: %{type: :number},
        token0_price_usd: %{type: :number},
        token1_price_usd: %{type: :number},
        estimated_gas_usd: %{type: :number},
        min_fee_to_gas_ratio: %{type: :number},
        auto_compound: %{type: :boolean}
      },
      required: ["tokens_owed0", "tokens_owed1", "token0_price_usd", "token1_price_usd"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        total_fees_usd: %{type: :number},
        net_profit_usd: %{type: :number},
        should_collect: %{type: :boolean},
        action_taken: %{type: :string},
        compounded_token0: %{type: :number},
        compounded_token1: %{type: :number}
      },
      required: ["total_fees_usd", "should_collect", "action_taken"]
    }

  def handler(input, _ctx) do
    owed0 = Map.fetch!(input, :tokens_owed0)
    owed1 = Map.fetch!(input, :tokens_owed1)
    p0 = Map.fetch!(input, :token0_price_usd)
    p1 = Map.fetch!(input, :token1_price_usd)
    gas_usd = Map.get(input, :estimated_gas_usd, 1.50)
    min_ratio = Map.get(input, :min_fee_to_gas_ratio, 5.0)
    auto_compound = Map.get(input, :auto_compound, true)

    total_usd = owed0 * p0 + owed1 * p1
    should_collect = total_usd >= gas_usd * min_ratio

    action_taken =
      cond do
        not should_collect -> "hold_accruing"
        auto_compound -> "collect_and_compound"
        true -> "collect_to_treasury"
      end

    # Balanced 50/50 USD split for in-range compounding
    half_net_usd = max(total_usd - gas_usd, 0.0) / 2.0
    comp0 = if should_collect and auto_compound and p0 > 0, do: Float.round(half_net_usd / p0, 8), else: 0.0
    comp1 = if should_collect and auto_compound and p1 > 0, do: Float.round(half_net_usd / p1, 8), else: 0.0

    {:ok,
     %{
       total_fees_usd: Float.round(total_usd, 4),
       net_profit_usd: Float.round(total_usd - gas_usd, 4),
       should_collect: should_collect,
       action_taken: action_taken,
       compounded_token0: comp0,
       compounded_token1: comp1
     }}
  end
end
