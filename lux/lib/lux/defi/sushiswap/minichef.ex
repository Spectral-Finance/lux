defmodule Lux.Defi.SushiSwap.MiniChef do
  @moduledoc """
  SushiSwap MiniChefV2 staking and reward distribution logic:
  - Deposit and withdrawal of LP tokens into farming pools
  - Accrual of pending SUSHI rewards
  - Harvesting rewards and updating reward debt
  """

  @precision 1_000_000_000_000

  @type user_stake :: %{
          user_address: String.t(),
          pid: non_neg_integer(),
          amount: non_neg_integer(),
          reward_debt: non_neg_integer()
        }

  @type farm_pool :: %{
          pid: non_neg_integer(),
          lp_token: String.t(),
          alloc_point: pos_integer(),
          acc_sushi_per_share: non_neg_integer(),
          total_staked: non_neg_integer()
        }

  @doc """
  Calculates accrued pending SUSHI rewards for a user stake.
  """
  @spec calculate_pending_sushi(user_stake(), farm_pool()) :: float()
  def calculate_pending_sushi(user_stake, farm_pool) do
    if user_stake.amount == 0 do
      0.0
    else
      accumulated = div(user_stake.amount * farm_pool.acc_sushi_per_share, @precision)
      pending_raw = max(accumulated - user_stake.reward_debt, 0)
      pending_raw / 1_000_000_000_000_000_000.0
    end
  end

  @doc """
  Deposits LP tokens into MiniChef pool.
  """
  @spec deposit(user_stake(), farm_pool(), non_neg_integer()) ::
          {:ok, user_stake(), farm_pool(), float()}
  def deposit(user_stake, farm_pool, amount) when amount >= 0 do
    pending = calculate_pending_sushi(user_stake, farm_pool)
    new_amount = user_stake.amount + amount
    new_debt = div(new_amount * farm_pool.acc_sushi_per_share, @precision)

    updated_user = %{user_stake | amount: new_amount, reward_debt: new_debt}
    updated_pool = %{farm_pool | total_staked: farm_pool.total_staked + amount}

    {:ok, updated_user, updated_pool, pending}
  end

  @doc """
  Harvests pending SUSHI rewards without modifying staked LP balance.
  """
  @spec harvest(user_stake(), farm_pool()) :: {:ok, user_stake(), float()}
  def harvest(user_stake, farm_pool) do
    pending = calculate_pending_sushi(user_stake, farm_pool)
    new_debt = div(user_stake.amount * farm_pool.acc_sushi_per_share, @precision)

    updated_user = %{user_stake | reward_debt: new_debt}
    {:ok, updated_user, pending}
  end
end
