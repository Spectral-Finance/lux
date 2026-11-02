defmodule Lux.Defi.Curve.GaugeManager do
  @moduledoc """
  Manages Curve LiquidityGauge staking, unstaking, veCRV boost calculation,
  and CRV rewards claiming.
  """

  alias Lux.Defi.Curve.Math
  alias Lux.Defi.Curve.PositionManager

  @doc """
  Stakes LP tokens into a Curve LiquidityGauge.
  """
  @spec stake(PositionManager.position(), non_neg_integer()) ::
          {:ok, PositionManager.position()} | {:error, :insufficient_lp}
  def stake(position, amount) when is_integer(amount) and amount > 0 do
    if amount > position.lp_balance do
      {:error, :insufficient_lp}
    else
      updated = %{
        position
        | lp_balance: position.lp_balance - amount,
          staked_in_gauge: position.staked_in_gauge + amount
      }

      {:ok, updated}
    end
  end

  @doc """
  Unstakes LP tokens from a Curve LiquidityGauge.
  """
  @spec unstake(PositionManager.position(), non_neg_integer()) ::
          {:ok, PositionManager.position()} | {:error, :insufficient_staked_lp}
  def unstake(position, amount) when is_integer(amount) and amount > 0 do
    if amount > position.staked_in_gauge do
      {:error, :insufficient_staked_lp}
    else
      updated = %{
        position
        | lp_balance: position.lp_balance + amount,
          staked_in_gauge: position.staked_in_gauge - amount
      }

      {:ok, updated}
    end
  end

  @doc """
  Claims accrued CRV rewards for a staked position.
  """
  @spec claim_rewards(PositionManager.position(), float()) :: {PositionManager.position(), float()}
  def claim_rewards(position, accrued_crv \\ 0.0) do
    total_claimed = position.unclaimed_crv + accrued_crv
    updated = %{position | unclaimed_crv: 0.0}
    {updated, total_claimed}
  end

  @doc """
  Calculates veCRV boost factor and effective working balance for user in gauge.
  """
  @spec calculate_boost(number(), number(), number(), number()) :: %{
          boost: float(),
          working_balance: float(),
          max_boosted?: boolean()
        }
  def calculate_boost(user_lp, total_lp, user_vecrv, total_vecrv) do
    boost = Math.calculate_gauge_boost(user_lp, total_lp, user_vecrv, total_vecrv)
    working_balance = min(user_lp, 0.4 * user_lp + 0.6 * total_lp * (max(user_vecrv, 0.0) / max(total_vecrv, 1.0)))

    %{
      boost: boost,
      working_balance: Float.round(working_balance, 4),
      max_boosted?: boost >= 2.49
    }
  end
end
