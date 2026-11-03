defmodule Lux.Beams.Defi.PancakeSwap.YieldFarmingBeam do
  @moduledoc """
  A coordinated workflow beam for PancakeSwap yield farming optimization:
  1. Computes pool APY (trading fee APR + CAKE emission APR)
  2. Evaluates auto-compounding viability and plans re-investment
  3. Executes or simulates staking into MasterChef
  """

  use Lux.Beam,
    name: "PancakeSwap Yield Farming Beam",
    description: "Evaluates PancakeSwap pool APY, plans compounding, and coordinates farm staking",
    input_schema: %{
      type: :object,
      properties: %{
        user_address: %{type: :string, description: "Wallet address of user"},
        pid: %{type: :integer, description: "MasterChef Pool ID"},
        amount: %{type: :integer, description: "LP token deposit amount"},
        tvl_usd: %{type: :number, description: "Pool TVL in USD"},
        daily_vol_usd: %{type: :number, description: "Pool 24h volume in USD"},
        cake_price_usd: %{type: :number, default: 2.50},
        price0_usd: %{type: :number, default: 1.0},
        price1_usd: %{type: :number, default: 1.0}
      },
      required: ["user_address", "pid", "amount", "tvl_usd", "daily_vol_usd"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        apy_metrics: %{type: :object},
        stake_result: %{type: :object}
      },
      required: ["status"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Defi.PancakeSwap.GetPoolApyPrism
  alias Lux.Prisms.Defi.PancakeSwap.AutoCompoundPrism
  alias Lux.Prisms.Defi.PancakeSwap.StakeFarmPrism

  sequence do
    step(:pool_apy, GetPoolApyPrism, %{
      tvl_usd: [:input, :tvl_usd],
      daily_vol_usd: [:input, :daily_vol_usd],
      cake_price_usd: [:input, :cake_price_usd]
    })

    step(:compound_plan, AutoCompoundPrism, %{
      pending_cake: 10.0,
      cake_price_usd: [:input, :cake_price_usd],
      price0_usd: [:input, :price0_usd],
      price1_usd: [:input, :price1_usd]
    })

    step(:stake, StakeFarmPrism, %{
      user_address: [:input, :user_address],
      pid: [:input, :pid],
      amount: [:input, :amount]
    })
  end
end
