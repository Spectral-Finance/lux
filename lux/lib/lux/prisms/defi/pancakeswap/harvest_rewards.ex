defmodule Lux.Prisms.Defi.PancakeSwap.HarvestRewardsPrism do
  @moduledoc """
  Harvests accumulated CAKE farming rewards from PancakeSwap MasterChef.
  """

  use Lux.Prism,
    name: "Harvest PancakeSwap Rewards",
    description: "Harvests accrued CAKE rewards from a MasterChef pool without changing staked LP balance",
    input_schema: %{
      type: :object,
      properties: %{
        user_address: %{type: :string, description: "Staker address"},
        pid: %{type: :integer, description: "MasterChef Pool ID"},
        staked_amount: %{type: :integer, description: "Current staked amount in wei"},
        reward_debt: %{type: :integer, default: 0},
        acc_cake_per_share: %{type: :integer, default: 1_000_000_000_000}
      },
      required: ["user_address", "pid", "staked_amount"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        user_address: %{type: :string},
        pid: %{type: :integer},
        harvested_cake: %{type: :number},
        status: %{type: :string}
      },
      required: ["user_address", "pid", "harvested_cake", "status"]
    }

  alias Lux.Defi.PancakeSwap.MasterChef

  def handler(input, _ctx) do
    user_addr = Map.get(input, :user_address) || Map.get(input, "user_address")
    pid = Map.get(input, :pid) || Map.get(input, "pid", 0)
    staked_amt = Map.get(input, :staked_amount) || Map.get(input, "staked_amount", 0)
    reward_debt = Map.get(input, :reward_debt) || Map.get(input, "reward_debt", 0)
    acc_cake = Map.get(input, :acc_cake_per_share) || Map.get(input, "acc_cake_per_share", 1_000_000_000_000)

    user = %{
      user_address: user_addr,
      pid: pid,
      amount: staked_amt,
      reward_debt: reward_debt
    }

    pool = %{
      pid: pid,
      lp_token: "0xLPTokenAddress",
      alloc_point: 100,
      total_alloc_point: 1000,
      acc_cake_per_share: acc_cake,
      cake_per_second: 1.0,
      total_staked: 10_000_000_000_000_000_000
    }

    {:ok, _updated_user, pending_cake} = MasterChef.harvest(user, pool)

    {:ok,
     %{
       user_address: user_addr,
       pid: pid,
       harvested_cake: pending_cake,
       status: "harvested"
     }}
  end
end
