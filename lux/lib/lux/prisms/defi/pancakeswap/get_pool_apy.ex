defmodule Lux.Prisms.Defi.PancakeSwap.GetPoolApyPrism do
  @moduledoc """
  Calculates trading fee APR, CAKE emission farming APR, and daily compounded APY for PancakeSwap.
  """

  use Lux.Prism,
    name: "Get PancakeSwap Pool APY",
    description: "Calculates LP fee APR, CAKE farming APR, and compounded APY for a PancakeSwap pool",
    input_schema: %{
      type: :object,
      properties: %{
        tvl_usd: %{type: :number, description: "Total value locked in USD"},
        daily_vol_usd: %{type: :number, description: "24h trading volume in USD"},
        pool_fee_rate: %{type: :number, default: 0.0025},
        cake_per_sec: %{type: :number, default: 1.0},
        alloc_point: %{type: :integer, default: 100},
        total_alloc: %{type: :integer, default: 1000},
        cake_price_usd: %{type: :number, default: 2.50}
      },
      required: ["tvl_usd", "daily_vol_usd"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        fee_apr_pct: %{type: :number},
        farming_apr_pct: %{type: :number},
        total_apr_pct: %{type: :number},
        compounded_apy_pct: %{type: :number}
      },
      required: ["fee_apr_pct", "farming_apr_pct", "total_apr_pct", "compounded_apy_pct"]
    }

  alias Lux.Defi.PancakeSwap.FarmingEngine

  def handler(input, _ctx) do
    tvl = Map.get(input, :tvl_usd) || Map.get(input, "tvl_usd", 1_000_000.0)
    vol = Map.get(input, :daily_vol_usd) || Map.get(input, "daily_vol_usd", 100_000.0)
    fee_rate = Map.get(input, :pool_fee_rate) || Map.get(input, "pool_fee_rate", 0.0025)
    cake_sec = Map.get(input, :cake_per_sec) || Map.get(input, "cake_per_sec", 1.0)
    alloc = Map.get(input, :alloc_point) || Map.get(input, "alloc_point", 100)
    tot_alloc = Map.get(input, :total_alloc) || Map.get(input, "total_alloc", 1000)
    cake_px = Map.get(input, :cake_price_usd) || Map.get(input, "cake_price_usd", 2.50)

    result = FarmingEngine.calculate_pool_apy(tvl * 1.0, vol * 1.0, fee_rate * 1.0, cake_sec * 1.0, alloc, tot_alloc, cake_px * 1.0)

    {:ok, result}
  end
end
