defmodule Lux.Web3.Curve.PositionLedger do
  @moduledoc """
  An atomic, process-backed ledger of Curve stablecoin positions.

  The ledger serialises all mutations through an `Agent`, so concurrent
  withdrawals from the same pool can never over-draw (double-spend) a position:
  the first accepted withdrawal decrements the balance and any subsequent
  withdrawal that would exceed the remaining balance is rejected with
  `{:error, :insufficient_position}`.
  """

  @doc """
  Starts a ledger process initialised with the given positions map.
  """
  @spec start_link(term()) :: {:ok, pid()} | {:error, term()}
  def start_link, do: start_link(%{})

  def start_link(positions) when is_map(positions), do: Agent.start_link(fn -> positions end)
  def start_link(_positions), do: {:error, :invalid_positions}

  @doc """
  Returns the current balance for `pool` (defaults to `0`).
  """
  @spec balance(Agent.agent(), term()) :: non_neg_integer()
  def balance(ledger, pool), do: Agent.get(ledger, &Map.get(&1, pool, 0))

  @doc """
  Atomically deposits `amount` into `pool`.
  """
  @spec deposit(Agent.agent(), term(), term()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def deposit(ledger, pool, amount) when is_integer(amount) and amount > 0 do
    Agent.get_and_update(ledger, fn positions ->
      new_balance = Map.get(positions, pool, 0) + amount
      {{:ok, new_balance}, Map.put(positions, pool, new_balance)}
    end)
  end

  def deposit(_ledger, _pool, _amount), do: {:error, :invalid_amount}

  @doc """
  Atomically withdraws `amount` from `pool` when the position is sufficient.
  """
  @spec withdraw(Agent.agent(), term(), term()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def withdraw(ledger, pool, amount) when is_integer(amount) and amount > 0 do
    Agent.get_and_update(ledger, fn positions ->
      current = Map.get(positions, pool, 0)

      if current >= amount do
        new_balance = current - amount
        {{:ok, new_balance}, Map.put(positions, pool, new_balance)}
      else
        {{:error, :insufficient_position}, positions}
      end
    end)
  end

  def withdraw(_ledger, _pool, _amount), do: {:error, :invalid_amount}
end
