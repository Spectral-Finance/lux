defmodule Lux.Prisms.Defi.SushiSwap.MiniChefStakePrism do
  @moduledoc """
  Deposits and stakes LP tokens into SushiSwap MiniChefV2 farming contracts.
  """

  use Lux.Prism,
    name: "SushiSwap MiniChef Stake",
    description: "Deposits LP tokens into MiniChef pool to accrue SUSHI yield rewards",
    input_schema: %{
      type: :object,
      properties: %{
        user_address: %{type: :string, description: "Staker address"},
        pid: %{type: :integer, description: "MiniChef Pool ID"},
        amount: %{type: :integer, description: "Raw amount of LP tokens to stake"},
        current_staked: %{type: :integer, default: 0},
        reward_debt: %{type: :integer, default: 0},
        acc_sushi_per_share: %{type: :integer, default: 1_000_000_000_000}
      },
      required: ["user_address", "pid", "amount"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        user_address: %{type: :string},
        pid: %{type: :integer},
        new_staked_balance: %{type: :integer},
        harvested_sushi: %{type: :number},
        status: %{type: :string}
      },
      required: ["user_address", "pid", "new_staked_balance", "status"]
    }

  alias Lux.Defi.SushiSwap.MiniChef

  def handler(input, _ctx) do
    user_addr = Map.get(input, :user_address) || Map.get(input, "user_address")
    pid = Map.get(input, :pid) || Map.get(input, "pid", 0)
    amt = Map.get(input, :amount) || Map.get(input, "amount", 0)
    curr_staked = Map.get(input, :current_staked) || Map.get(input, "current_staked", 0)
    r_debt = Map.get(input, :reward_debt) || Map.get(input, "reward_debt", 0)
    acc = Map.get(input, :acc_sushi_per_share) || Map.get(input, "acc_sushi_per_share", 1_000_000_000_000)

    user = %{user_address: user_addr, pid: pid, amount: curr_staked, reward_debt: r_debt}
    pool = %{pid: pid, lp_token: "0xSushiLPToken", alloc_point: 100, acc_sushi_per_share: acc, total_staked: 10_000_000_000_000_000_000}

    {:ok, updated_user, _updated_pool, pending} = MiniChef.deposit(user, pool, amt)

    {:ok,
     %{
       user_address: user_addr,
       pid: pid,
       new_staked_balance: updated_user.amount,
       harvested_sushi: pending,
       status: "staked"
     }}
  end
end
