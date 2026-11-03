defmodule Lux.Defi.SushiSwap.RouteProcessor do
  @moduledoc """
  SushiSwap RouteProcessor multi-hop swap and slippage estimation engine.
  Computes output amounts using constant-product AMM mechanics (0.30% fee).
  """

  @fee_multiplier 997
  @fee_base 1000

  @doc """
  Calculates single-pool swap output amount.
  """
  @spec get_amount_out(float(), float(), float()) :: float()
  def get_amount_out(amount_in, reserve_in, reserve_out) when amount_in > 0 and reserve_in > 0 and reserve_out > 0 do
    amount_in_with_fee = amount_in * @fee_multiplier
    numerator = amount_in_with_fee * reserve_out
    denominator = reserve_in * @fee_base + amount_in_with_fee

    Float.round(numerator / denominator, 6)
  end

  def get_amount_out(_, _, _), do: 0.0

  @doc """
  Calculates multi-hop swap route across pools.
  """
  @spec route_multihop(float(), list(map())) :: %{
          amount_in: float(),
          amount_out: float(),
          price_impact_pct: float(),
          hops: pos_integer()
        }
  def route_multihop(amount_in, pools) when is_list(pools) and length(pools) > 0 and amount_in > 0 do
    initial_rate =
      Enum.reduce(pools, 1.0, fn p, acc ->
        acc * (p.reserve_out / p.reserve_in)
      end)

    final_amount_out =
      Enum.reduce(pools, amount_in, fn p, current_in ->
        get_amount_out(current_in, p.reserve_in, p.reserve_out)
      end)

    ideal_out = amount_in * initial_rate
    price_impact = if ideal_out > 0, do: Float.round((ideal_out - final_amount_out) / ideal_out * 100.0, 2), else: 0.0

    %{
      amount_in: amount_in,
      amount_out: final_amount_out,
      price_impact_pct: price_impact,
      hops: length(pools)
    }
  end

  def route_multihop(amount_in, _) do
    %{amount_in: amount_in, amount_out: 0.0, price_impact_pct: 0.0, hops: 0}
  end
end
