defmodule Lux.Defi.PancakeSwap.MasterChef do
  @moduledoc """
  PancakeSwap MasterChef yield farming contract interaction logic:
  - Staking LP tokens into MasterChef pools (deposit)
  - Withdrawing LP tokens from farm (withdraw)
  - Pending CAKE reward accrual calculations
  - Harvesting rewards and updating reward debt
  """

  @precision 1_000_000_000_000

  @type farm_pool :: %{
          pid: non_neg_integer(),
          lp_token: String.t(),
          alloc_point: pos_integer(),
          total_alloc_point: pos_integer(),
          acc_cake_per_share: non_neg_integer(),
          cake_per_second: float(),
          total_staked: non_neg_integer()
        }

  @type user_stake :: %{
          user_address: String.t(),
          pid: non_neg_integer(),
          amount: non_neg_integer(),
          reward_debt: non_neg_integer()
        }

  @doc """
  Calculates accrued pending CAKE rewards for a user stake.
  """
  @spec calculate_pending_cake(user_stake(), farm_pool()) :: float()
  def calculate_pending_cake(user_stake, farm_pool) do
    if user_stake.amount == 0 do
      0.0
    else
      accumulated = div(user_stake.amount * farm_pool.acc_cake_per_share, @precision)
      pending_raw = max(accumulated - user_stake.reward_debt, 0)
      pending_raw / 1_000_000_000_000_000_000.0
    end
  end

  @doc """
  Simulates staking LP tokens into MasterChef, updating user balance, reward debt, and harvesting pending rewards.
  """
  @spec deposit(user_stake(), farm_pool(), non_neg_integer()) ::
          {:ok, user_stake(), farm_pool(), float()}
  def deposit(user_stake, farm_pool, deposit_amount) when deposit_amount >= 0 do
    pending_cake = calculate_pending_cake(user_stake, farm_pool)

    new_amount = user_stake.amount + deposit_amount
    new_reward_debt = div(new_amount * farm_pool.acc_cake_per_share, @precision)

    updated_user = %{
      user_stake
      | amount: new_amount,
        reward_debt: new_reward_debt
    }

    updated_pool = %{
      farm_pool
      | total_staked: farm_pool.total_staked + deposit_amount
    }

    {:ok, updated_user, updated_pool, pending_cake}
  end

  @doc """
  Simulates withdrawing LP tokens from MasterChef.
  """
  @spec withdraw(user_stake(), farm_pool(), non_neg_integer()) ::
          {:ok, user_stake(), farm_pool(), float()} | {:error, :insufficient_staked_balance}
  def withdraw(user_stake, farm_pool, withdraw_amount) when withdraw_amount > 0 do
    if withdraw_amount > user_stake.amount do
      {:error, :insufficient_staked_balance}
    else
      pending_cake = calculate_pending_cake(user_stake, farm_pool)

      new_amount = user_stake.amount - withdraw_amount
      new_reward_debt = div(new_amount * farm_pool.acc_cake_per_share, @precision)

      updated_user = %{
        user_stake
        | amount: new_amount,
          reward_debt: new_reward_debt
      }

      updated_pool = %{
        farm_pool
        | total_staked: farm_pool.total_staked - withdraw_amount
      }

      {:ok, updated_user, updated_pool, pending_cake}
    end
  end

  @doc """
  Harvests accumulated CAKE rewards without changing staked balance.
  """
  @spec harvest(user_stake(), farm_pool()) :: {:ok, user_stake(), float()}
  def harvest(user_stake, farm_pool) do
    pending_cake = calculate_pending_cake(user_stake, farm_pool)
    new_reward_debt = div(user_stake.amount * farm_pool.acc_cake_per_share, @precision)

    updated_user = %{user_stake | reward_debt: new_reward_debt}
    {:ok, updated_user, pending_cake}
  end
end
