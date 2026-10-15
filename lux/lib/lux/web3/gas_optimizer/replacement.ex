defmodule Lux.Web3.GasOptimizer.Replacement do
  @moduledoc """
  EIP-1559 Replace-By-Fee (RBF) transaction speed-up and cancellation builder.

  Enforces EVM mempool replacement rules requiring the same sender and `nonce`
  and at least a `10%` (`1.12x` default) fee bump on both `max_fee_per_gas` and
  `max_priority_fee_per_gas`.
  """

  @min_bump_ratio 1.10
  @default_bump_ratio 1.15

  @doc """
  Creates a replacement transaction that speeds up a pending transaction by
  bumping its fee parameters while preserving `from`, `to`, `value`, `data`, and `nonce`.
  """
  @spec speed_up(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def speed_up(pending_tx, opts \\ []) when is_map(pending_tx) do
    bump = Keyword.get(opts, :bump_ratio, @default_bump_ratio)

    if bump < @min_bump_ratio do
      {:error, :insufficient_fee_bump}
    else
      {:ok, apply_fee_bump(pending_tx, bump, :speed_up)}
    end
  end

  @doc """
  Creates a cancellation transaction (`value: 0`, `to: from`, `data: "0x"`,
  `gas_limit: 21_000`) with bumped fees and the exact same `nonce` as the pending tx.
  """
  @spec cancel(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def cancel(pending_tx, opts \\ []) when is_map(pending_tx) do
    bump = Keyword.get(opts, :bump_ratio, @default_bump_ratio)

    if bump < @min_bump_ratio do
      {:error, :insufficient_fee_bump}
    else
      bumped = apply_fee_bump(pending_tx, bump, :cancel)
      sender = Map.get(pending_tx, :from) || Map.get(pending_tx, "from")

      {:ok,
       Map.merge(bumped, %{
         to: sender,
         value: 0,
         data: "0x",
         gas_limit: 21_000
       })}
    end
  end

  defp apply_fee_bump(tx, bump, replacement_type) do
    old_max_fee = Map.get(tx, :max_fee_per_gas, 30_000_000_000)
    old_prio_fee = Map.get(tx, :max_priority_fee_per_gas, 1_500_000_000)
    old_gas_price = Map.get(tx, :gas_price)

    new_max_fee = round(old_max_fee * bump)
    new_prio_fee = round(old_prio_fee * bump)
    new_gas_price = if is_integer(old_gas_price), do: round(old_gas_price * bump), else: nil

    tx
    |> Map.put(:max_fee_per_gas, new_max_fee)
    |> Map.put(:max_priority_fee_per_gas, new_prio_fee)
    |> Map.put(:gas_price, new_gas_price)
    |> Map.put(:replacement_type, replacement_type)
    |> Map.put(:replaced_nonce, Map.get(tx, :nonce, 0))
  end
end
