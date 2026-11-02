defmodule Lux.Defi.UniswapV3.Math do
  @moduledoc """
  Core mathematical operations for Uniswap V3 concentrated liquidity:
  - Q64.96 fixed-point arithmetic
  - Tick to Price and Price to Tick conversions
  - Liquidity to token amounts calculation
  - Token amounts to Liquidity calculation
  - Usable tick alignment based on fee tier tick spacing
  """

  @q96 79_228_162_514_264_337_593_543_950_336
  @min_tick -887_272
  @max_tick 887_272

  @doc """
  Converts an integer tick into price (token1 / token0) adjusted for decimal differences.
  price = (1.0001 ^ tick) * (10 ^ (decimals0 - decimals1))
  """
  @spec tick_to_price(integer(), non_neg_integer(), non_neg_integer()) :: float()
  def tick_to_price(tick, decimals0 \\ 18, decimals1 \\ 18) when is_integer(tick) do
    clamped_tick = clamp_tick(tick)
    raw_price = :math.pow(1.0001, clamped_tick)
    decimal_adjustment = :math.pow(10, decimals0 - decimals1)
    raw_price * decimal_adjustment
  end

  @doc """
  Converts a human-readable price into the closest integer tick index.
  tick = round(ln(price / 10^(decimals0 - decimals1)) / ln(1.0001))
  """
  @spec price_to_tick(number(), non_neg_integer(), non_neg_integer()) :: integer()
  def price_to_tick(price, decimals0 \\ 18, decimals1 \\ 18) when is_number(price) and price > 0 do
    decimal_adjustment = :math.pow(10, decimals0 - decimals1)
    raw_price = price / decimal_adjustment
    raw_tick = round(:math.log(raw_price) / :math.log(1.0001))
    clamp_tick(raw_tick)
  end

  @doc """
  Computes the square root price in Q64.96 notation (sqrtPriceX96) from a tick.
  sqrtPriceX96 = round(1.0001 ^ (tick / 2) * 2^96)
  """
  @spec tick_to_sqrt_price_x96(integer()) :: pos_integer()
  def tick_to_sqrt_price_x96(tick) when is_integer(tick) do
    clamped = clamp_tick(tick)
    sqrt_ratio = :math.pow(1.0001, clamped / 2.0)
    round(sqrt_ratio * @q96)
  end

  @doc """
  Computes human-readable price from sqrtPriceX96.
  price = (sqrtPriceX96 / 2^96)^2 * 10^(decimals0 - decimals1)
  """
  @spec sqrt_price_x96_to_price(pos_integer(), non_neg_integer(), non_neg_integer()) :: float()
  def sqrt_price_x96_to_price(sqrt_price_x96, decimals0 \\ 18, decimals1 \\ 18)
      when is_integer(sqrt_price_x96) and sqrt_price_x96 > 0 do
    ratio = sqrt_price_x96 / @q96
    raw_price = ratio * ratio
    decimal_adjustment = :math.pow(10, decimals0 - decimals1)
    raw_price * decimal_adjustment
  end

  @doc """
  Calculates token0 and token1 amounts required for a given liquidity value and price range.
  """
  @spec get_amounts_for_liquidity(pos_integer(), pos_integer(), pos_integer(), non_neg_integer()) ::
          %{amount0: non_neg_integer(), amount1: non_neg_integer()}
  def get_amounts_for_liquidity(sqrt_curr, sqrt_a, sqrt_b, liquidity)
      when is_integer(sqrt_curr) and is_integer(sqrt_a) and is_integer(sqrt_b) and is_integer(liquidity) do
    {sqrt_lower, sqrt_upper} =
      if sqrt_a <= sqrt_b, do: {sqrt_a, sqrt_b}, else: {sqrt_b, sqrt_a}

    cond do
      sqrt_curr <= sqrt_lower ->
        # Current price below range: position is 100% token0
        amount0 = get_amount0_for_liquidity(sqrt_lower, sqrt_upper, liquidity)
        %{amount0: amount0, amount1: 0}

      sqrt_curr >= sqrt_upper ->
        # Current price above range: position is 100% token1
        amount1 = get_amount1_for_liquidity(sqrt_lower, sqrt_upper, liquidity)
        %{amount0: 0, amount1: amount1}

      true ->
        # Current price in range: position holds both tokens
        amount0 = get_amount0_for_liquidity(sqrt_curr, sqrt_upper, liquidity)
        amount1 = get_amount1_for_liquidity(sqrt_lower, sqrt_curr, liquidity)
        %{amount0: amount0, amount1: amount1}
    end
  end

  @doc """
  Calculates the liquidity $L$ provided by given amounts of token0 and token1 over a price range.
  """
  @spec get_liquidity_for_amounts(pos_integer(), pos_integer(), pos_integer(), non_neg_integer(), non_neg_integer()) ::
          non_neg_integer()
  def get_liquidity_for_amounts(sqrt_curr, sqrt_a, sqrt_b, amount0, amount1)
      when is_integer(sqrt_curr) and is_integer(sqrt_a) and is_integer(sqrt_b) do
    {sqrt_lower, sqrt_upper} =
      if sqrt_a <= sqrt_b, do: {sqrt_a, sqrt_b}, else: {sqrt_b, sqrt_a}

    cond do
      sqrt_curr <= sqrt_lower ->
        get_liquidity_for_amount0(sqrt_lower, sqrt_upper, amount0)

      sqrt_curr >= sqrt_upper ->
        get_liquidity_for_amount1(sqrt_lower, sqrt_upper, amount1)

      true ->
        liq0 = get_liquidity_for_amount0(sqrt_curr, sqrt_upper, amount0)
        liq1 = get_liquidity_for_amount1(sqrt_lower, sqrt_curr, amount1)
        min(liq0, liq1)
    end
  end

  @doc """
  Rounds a tick to the nearest valid tick satisfying the given fee tier tick spacing.
  """
  @spec nearest_usable_tick(integer(), pos_integer()) :: integer()
  def nearest_usable_tick(tick, tick_spacing) when is_integer(tick) and is_integer(tick_spacing) and tick_spacing > 0 do
    rounded = round(tick / tick_spacing) * tick_spacing
    clamp_tick(rounded)
  end

  @doc """
  Clamps tick to Uniswap V3 valid range [-887272, 887272].
  """
  @spec clamp_tick(integer()) :: integer()
  def clamp_tick(tick) when is_integer(tick) do
    cond do
      tick < @min_tick -> @min_tick
      tick > @max_tick -> @max_tick
      true -> tick
    end
  end

  # --- Internal Helpers ---

  defp get_amount0_for_liquidity(sqrt_lower, sqrt_upper, liquidity) do
    # amount0 = L * (sqrt_upper - sqrt_lower) / (sqrt_upper * sqrt_lower) * 2^96
    numerator = liquidity * (sqrt_upper - sqrt_lower) * @q96
    denominator = sqrt_upper * sqrt_lower
    div(numerator, denominator)
  end

  defp get_amount1_for_liquidity(sqrt_lower, sqrt_upper, liquidity) do
    # amount1 = L * (sqrt_upper - sqrt_lower) / 2^96
    div(liquidity * (sqrt_upper - sqrt_lower), @q96)
  end

  defp get_liquidity_for_amount0(sqrt_lower, sqrt_upper, amount0) do
    # L = amount0 * (sqrt_upper * sqrt_lower) / (sqrt_upper - sqrt_lower) / 2^96
    intermediate = div(amount0 * sqrt_upper, @q96) * sqrt_lower
    div(intermediate, sqrt_upper - sqrt_lower)
  end

  defp get_liquidity_for_amount1(sqrt_lower, sqrt_upper, amount1) do
    # L = amount1 * 2^96 / (sqrt_upper - sqrt_lower)
    div(amount1 * @q96, sqrt_upper - sqrt_lower)
  end
end
