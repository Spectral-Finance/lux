defmodule Lux.Defi.Curve.PositionManager do
  @moduledoc """
  Manages Curve LP token positions: deposits, balanced withdrawals, single-coin withdrawals,
  and USD valuation based on pool virtual price.
  """

  alias Lux.Defi.Curve.Math

  @type position :: %{
          id: String.t(),
          owner: String.t(),
          pool_id: String.t(),
          lp_balance: non_neg_integer(),
          staked_in_gauge: non_neg_integer(),
          unclaimed_crv: float(),
          created_at: DateTime.t()
        }

  @doc """
  Creates a new Curve LP position struct.
  """
  @spec create_position(String.t(), String.t(), keyword()) :: position()
  def create_position(owner, pool_id, opts \\ []) do
    %{
      id: "curve_pos_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)),
      owner: String.downcase(owner),
      pool_id: pool_id,
      lp_balance: Keyword.get(opts, :lp_balance, 0),
      staked_in_gauge: Keyword.get(opts, :staked_in_gauge, 0),
      unclaimed_crv: Keyword.get(opts, :unclaimed_crv, 0.0),
      created_at: DateTime.utc_now()
    }
  end

  @doc """
  Simulates deposit of coins into pool, computing LP tokens minted.
  """
  @spec deposit(position(), list(non_neg_integer()), list(non_neg_integer()), pos_integer(), non_neg_integer()) ::
          {:ok, position(), non_neg_integer()}
  def deposit(position, amounts, current_balances, amp, total_lp_supply) do
    minted_lp = Math.calc_lp_mint(amounts, current_balances, amp, total_lp_supply)
    updated = %{position | lp_balance: position.lp_balance + minted_lp}
    {:ok, updated, minted_lp}
  end

  @doc """
  Simulates a balanced withdrawal across all pool coins.
  """
  @spec withdraw_balanced(position(), non_neg_integer(), list(non_neg_integer()), non_neg_integer()) ::
          {:ok, position(), list(non_neg_integer())} | {:error, :insufficient_lp}
  def withdraw_balanced(position, lp_burn, current_balances, total_lp_supply) do
    if lp_burn > position.lp_balance do
      {:error, :insufficient_lp}
    else
      share = lp_burn / max(total_lp_supply, 1)

      withdrawn =
        Enum.map(current_balances, fn bal ->
          round(bal * share)
        end)

      updated = %{position | lp_balance: position.lp_balance - lp_burn}
      {:ok, updated, withdrawn}
    end
  end

  @doc """
  Calculates the total USD value of the position (wallet LP + gauge staked LP).
  """
  @spec position_value_usd(position(), float()) :: float()
  def position_value_usd(position, virtual_price) when virtual_price > 0 do
    total_lp = (position.lp_balance + position.staked_in_gauge) / 1_000_000_000_000_000_000.0
    Float.round(total_lp * virtual_price, 2)
  end
end
