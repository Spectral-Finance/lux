defmodule Lux.Web3.Curve.Rebalancer do
  @moduledoc """
  Automated rebalancing planner for Curve stablecoin positions.

  Given the current per-pool allocation and a target allocation expressed in
  basis points, `plan/3` returns the minimal set of deposits and withdrawals
  required to reach the target. The planner is pure and deterministic so the
  resulting action list can be applied atomically by an executor.
  """

  @bps 10_000

  @type allocations :: %{optional(term()) => non_neg_integer()}
  @type action :: %{pool: term(), action: :deposit | :withdraw, amount: pos_integer()}

  @doc """
  Builds a rebalancing plan.

  ## Arguments

    * `current` - map of pool => current value (non-negative integers)
    * `weights` - map of pool => target weight in bps; must be non-empty and sum
      to exactly `10_000`
    * `total_value` - total value to allocate across the pools (positive integer)

  ## Returns

  `{:ok, actions}` with only the required deposits/withdrawals (an empty list when
  already balanced) or a typed `{:error, reason}`.
  """
  @spec plan(term(), term(), term()) :: {:ok, [action()]} | {:error, atom()}
  def plan(current, weights, total_value) when is_map(current) and is_map(weights) do
    with :ok <- validate_total(total_value),
         :ok <- validate_current(current),
         :ok <- validate_weights(weights) do
      target = Map.new(weights, fn {pool, weight} -> {pool, div(total_value * weight, @bps)} end)

      actions =
        (Map.keys(current) ++ Map.keys(weights))
        |> Enum.uniq()
        |> Enum.map(fn pool ->
          have = Map.get(current, pool, 0)
          want = Map.get(target, pool, 0)
          build_action(pool, have, want)
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(& &1.pool)

      {:ok, actions}
    end
  end

  def plan(_current, _weights, _total_value), do: {:error, :invalid_input}

  defp build_action(pool, have, want) when want > have,
    do: %{pool: pool, action: :deposit, amount: want - have}

  defp build_action(pool, have, want) when want < have,
    do: %{pool: pool, action: :withdraw, amount: have - want}

  defp build_action(_pool, _have, _want), do: nil

  defp validate_total(total) when is_integer(total) and total > 0, do: :ok
  defp validate_total(_total), do: {:error, :invalid_total}

  defp validate_current(current) do
    if Enum.all?(current, fn {_pool, value} -> is_integer(value) and value >= 0 end) do
      :ok
    else
      {:error, :invalid_current}
    end
  end

  defp validate_weights(weights) when map_size(weights) == 0, do: {:error, :empty_target}

  defp validate_weights(weights) do
    valid? = Enum.all?(weights, fn {_pool, weight} -> is_integer(weight) and weight >= 0 end)

    cond do
      not valid? -> {:error, :invalid_allocation}
      Enum.sum(Map.values(weights)) != @bps -> {:error, :invalid_allocation}
      true -> :ok
    end
  end
end
