defmodule Lux.Integrations.UniswapV3.LiquidityManager do
  @moduledoc """
  Uniswap V3 concentrated liquidity position management, tick alignment,
  impermanent loss estimation, and automated range rebalancing (#78).
  """

  @fee_tier_spacings %{100 => 1, 500 => 10, 3000 => 60, 10_000 => 200}

  @doc """
  Aligns a raw tick index to the nearest valid tick spacing for the given fee tier.
  """
  def align_tick(tick, fee_tier) when is_integer(tick) do
    case Map.fetch(@fee_tier_spacings, fee_tier) do
      {:ok, spacing} -> {:ok, div(tick, spacing) * spacing}
      :error -> {:error, :unsupported_fee_tier}
    end
  end

  @doc """
  Computes standard Impermanent Loss percentage given price ratio `p_ratio = current_price / entry_price`.
  """
  def calculate_impermanent_loss_pct(p_ratio) when p_ratio > 0 do
    il = 2.0 * :math.sqrt(p_ratio) / (1.0 + p_ratio) - 1.0
    {:ok, Float.round(il * 100.0, 4)}
  end

  @doc """
  Checks whether a concentrated liquidity position requires rebalancing.
  """
  def needs_rebalance?(%{current_tick: cur, tick_lower: lower, tick_upper: upper}, buffer_ticks \\ 60)
      when lower < upper do
    cur <= lower + buffer_ticks or cur >= upper - buffer_ticks
  end
end
