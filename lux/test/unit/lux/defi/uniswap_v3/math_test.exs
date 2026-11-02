defmodule Lux.Defi.UniswapV3.MathTest do
  use ExUnit.Case, async: true

  alias Lux.Defi.UniswapV3.Math

  describe "tick_to_price/3 and price_to_tick/3" do
    test "converts tick 0 to price 1.0 when decimals are identical" do
      price = Math.tick_to_price(0, 18, 18)
      assert_in_delta price, 1.0, 0.0001
    end

    test "roundtrips price to tick and back" do
      initial_price = 2500.0
      tick = Math.price_to_tick(initial_price, 18, 6)
      reconstructed_price = Math.tick_to_price(tick, 18, 6)

      # Relative delta < 0.1%
      diff_ratio = abs(reconstructed_price - initial_price) / initial_price
      assert diff_ratio < 0.001
    end
  end

  describe "tick_to_sqrt_price_x96/1 and sqrt_price_x96_to_price/3" do
    test "tick 0 gives Q96 value (2^96)" do
      q96 = 79_228_162_514_264_337_593_543_950_336
      sqrt_p = Math.tick_to_sqrt_price_x96(0)
      assert sqrt_p == q96

      price = Math.sqrt_price_x96_to_price(sqrt_p, 18, 18)
      assert_in_delta price, 1.0, 0.0001
    end
  end

  describe "get_amounts_for_liquidity/4 and get_liquidity_for_amounts/5" do
    test "calculates correct amounts when inside range" do
      sqrt_curr = Math.tick_to_sqrt_price_x96(100)
      sqrt_a = Math.tick_to_sqrt_price_x96(0)
      sqrt_b = Math.tick_to_sqrt_price_x96(200)
      liquidity = 1_000_000_000

      amounts = Math.get_amounts_for_liquidity(sqrt_curr, sqrt_a, sqrt_b, liquidity)
      assert amounts.amount0 > 0
      assert amounts.amount1 > 0

      reconstructed_liq = Math.get_liquidity_for_amounts(sqrt_curr, sqrt_a, sqrt_b, amounts.amount0, amounts.amount1)
      assert_in_delta reconstructed_liq, liquidity, 1000
    end

    test "returns only token0 when price is below range" do
      sqrt_curr = Math.tick_to_sqrt_price_x96(50)
      sqrt_a = Math.tick_to_sqrt_price_x96(100)
      sqrt_b = Math.tick_to_sqrt_price_x96(200)
      liquidity = 1_000_000_000

      amounts = Math.get_amounts_for_liquidity(sqrt_curr, sqrt_a, sqrt_b, liquidity)
      assert amounts.amount0 > 0
      assert amounts.amount1 == 0
    end

    test "returns only token1 when price is above range" do
      sqrt_curr = Math.tick_to_sqrt_price_x96(250)
      sqrt_a = Math.tick_to_sqrt_price_x96(100)
      sqrt_b = Math.tick_to_sqrt_price_x96(200)
      liquidity = 1_000_000_000

      amounts = Math.get_amounts_for_liquidity(sqrt_curr, sqrt_a, sqrt_b, liquidity)
      assert amounts.amount0 == 0
      assert amounts.amount1 > 0
    end
  end

  describe "nearest_usable_tick/2" do
    test "aligns tick to specified tick spacing" do
      assert Math.nearest_usable_tick(103, 60) == 120
      assert Math.nearest_usable_tick(89, 60) == 60
      assert Math.nearest_usable_tick(15, 10) == 20
      assert Math.nearest_usable_tick(7, 1) == 7
    end
  end
end
