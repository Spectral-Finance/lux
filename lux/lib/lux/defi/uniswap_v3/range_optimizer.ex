defmodule Lux.Defi.UniswapV3.RangeOptimizer do
  @moduledoc """
  Calculates optimal price boundaries and tick ranges for Uniswap V3 concentrated liquidity:
  - Fixed-percentage strategies (:narrow, :moderate, :wide)
  - Volatility-adjusted dynamic ranges (standard deviations)
  - Directional asymmetric ranges (bullish, bearish)
  - Capital efficiency multiplier quantification
  - Strict tick-spacing alignment
  """

  alias Lux.Defi.UniswapV3.Math
  alias Lux.Defi.UniswapV3.PoolManager

  @type strategy :: :narrow | :moderate | :wide | :volatility | :bullish | :bearish

  @strategy_configs %{
    narrow: %{lower_pct: -0.03, upper_pct: 0.03, name: "Narrow (+/- 3%)"},
    moderate: %{lower_pct: -0.10, upper_pct: 0.10, name: "Moderate (+/- 10%)"},
    wide: %{lower_pct: -0.25, upper_pct: 0.25, name: "Wide (+/- 25%)"},
    bullish: %{lower_pct: -0.05, upper_pct: 0.20, name: "Bullish (-5% / +20%)"},
    bearish: %{lower_pct: -0.20, upper_pct: 0.05, name: "Bearish (-20% / +5%)"}
  }

  @doc """
  Computes optimal lower and upper ticks for a given current tick, fee tier, and strategy.
  """
  @spec calculate_range(integer(), pos_integer(), strategy() | map(), keyword()) ::
          {:ok, %{tick_lower: integer(), tick_upper: integer(), price_lower: float(), price_upper: float(), efficiency: float()}}
          | {:error, term()}
  def calculate_range(current_tick, fee, strategy \\ :moderate, opts \\ []) when is_integer(current_tick) do
    tick_spacing = PoolManager.tick_spacing_for_fee(fee)
    decimals0 = Keyword.get(opts, :decimals0, 18)
    decimals1 = Keyword.get(opts, :decimals1, 18)
    current_price = Math.tick_to_price(current_tick, decimals0, decimals1)

    {lower_ratio, upper_ratio} = resolve_ratios(strategy, opts)

    target_price_lower = current_price * (1.0 + lower_ratio)
    target_price_upper = current_price * (1.0 + upper_ratio)

    raw_tick_lower = Math.price_to_tick(target_price_lower, decimals0, decimals1)
    raw_tick_upper = Math.price_to_tick(target_price_upper, decimals0, decimals1)

    # Align with tick spacing
    tick_lower = Math.nearest_usable_tick(raw_tick_lower, tick_spacing)
    tick_upper = Math.nearest_usable_tick(raw_tick_upper, tick_spacing)

    # Ensure tick_lower < tick_upper
    tick_upper =
      if tick_upper <= tick_lower do
        tick_lower + tick_spacing
      else
        tick_upper
      end

    price_lower = Math.tick_to_price(tick_lower, decimals0, decimals1)
    price_upper = Math.tick_to_price(tick_upper, decimals0, decimals1)

    efficiency = calculate_capital_efficiency(price_lower, price_upper)

    {:ok,
     %{
       tick_lower: tick_lower,
       tick_upper: tick_upper,
       price_lower: price_lower,
       price_upper: price_upper,
       efficiency: efficiency,
       current_price: current_price
     }}
  end

  @doc """
  Calculates the capital efficiency multiplier of concentrated liquidity relative to full range (Uniswap V2).
  efficiency = 1 / (1 - sqrt(P_lower / P_upper))
  """
  @spec calculate_capital_efficiency(number(), number()) :: float()
  def calculate_capital_efficiency(price_lower, price_upper)
      when is_number(price_lower) and is_number(price_upper) and price_lower > 0 and price_upper > price_lower do
    ratio = price_lower / price_upper
    sqrt_ratio = :math.sqrt(ratio)
    denom = max(1.0 - sqrt_ratio, 0.0001)
    Float.round(1.0 / denom, 2)
  end

  def calculate_capital_efficiency(_, _), do: 1.0

  defp resolve_ratios(:volatility, opts) do
    # annualized volatility, e.g. 0.60 for 60%
    ann_vol = Keyword.get(opts, :annualized_volatility, 0.60)
    # 7-day expected range: 1.5 * vol * sqrt(7/365)
    horizon_days = Keyword.get(opts, :horizon_days, 7)
    delta = 1.5 * ann_vol * :math.sqrt(horizon_days / 365.0)
    {-delta, delta}
  end

  defp resolve_ratios(strat, _opts) when is_atom(strat) do
    case Map.get(@strategy_configs, strat) do
      %{lower_pct: l, upper_pct: u} -> {l, u}
      _ -> {-0.10, 0.10}
    end
  end

  defp resolve_ratios(%{lower_pct: l, upper_pct: u}, _opts), do: {l, u}
  defp resolve_ratios(_, _opts), do: {-0.10, 0.10}
end
