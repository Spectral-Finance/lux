defmodule Lux.Prisms.Defi.PancakeSwap.StakeFarmPrism do
  @moduledoc """
  Deposits/stakes LP tokens into PancakeSwap MasterChef yield farming contract.
  """

  use Lux.Prism,
    name: "Stake in PancakeSwap Farm",
    description: "Deposits LP tokens into MasterChef pool to earn CAKE yield rewards",
    input_schema: %{
      type: :object,
      properties: %{
        user_address: %{type: :string, description: "Staker address"},
        pid: %{type: :integer, description: "MasterChef Pool ID"},
        amount: %{type: :integer, description: "Raw LP token amount to stake"},
        current_staked: %{type: :integer, default: 0},
        reward_debt: %{type: :integer, default: 0},
        acc_cake_per_share: %{type: :integer, default: 1_000_000_000_000},
        total_staked: %{type: :integer, default: 10_000_000_000_000_000_000}
      },
      required: ["user_address", "pid", "amount"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        user_address: %{type: :string},
        pid: %{type: :integer},
        new_staked_balance: %{type: :integer},
        harvested_cake: %{type: :number},
        status: %{type: :string}
      },
      required: ["user_address", "pid", "new_staked_balance", "status"]
    }

  alias Lux.Defi.PancakeSwap.MasterChef

  def handler(input, _ctx) do
    user_addr = Map.get(input, :user_address) || Map.get(input, "user_address")
    pid = Map.get(input, :pid) || Map.get(input, "pid", 0)
    amount = Map.get(input, :amount) || Map.get(input, "amount", 0)
    current_staked = Map.get(input, :current_staked) || Map.get(input, "current_staked", 0)
    reward_debt = Map.get(input, :reward_debt) || Map.get(input, "reward_debt", 0)
    acc_cake = Map.get(input, :acc_cake_per_share) || Map.get(input, "acc_cake_per_share", 1_000_000_000_000)
    tot_staked = Map.get(input, :total_staked) || Map.get(input, "total_staked", 10_000_000_000_000_000_000)

    user = %{
      user_address: user_addr,
      pid: pid,
      amount: current_staked,
      reward_debt: reward_debt
    }

    pool = %{
      pid: pid,
      lp_token: "0xLPTokenAddress",
      alloc_point: 100,
      total_alloc_point: 1000,
      acc_cake_per_share: acc_cake,
      cake_per_second: 1.0,
      total_staked: tot_staked
    }

    case MasterChef.deposit(user, pool, amount) do
      {:ok, updated_user, _updated_pool, pending_cake} ->
        {:ok,
         %{
           user_address: user_addr,
           pid: pid,
           new_staked_balance: updated_user.amount,
           harvested_cake: pending_cake,
           status: "staked"
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
