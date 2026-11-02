defmodule Lux.Defi.UniswapV3.PositionManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Defi.UniswapV3.PositionManager
  alias Lux.Defi.UniswapV3.Math

  @weth "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
  @usdc "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"

  describe "create_position/1" do
    test "creates valid position when ticks are spaced properly" do
      params = %{
        token0: @usdc,
        token1: @weth,
        fee: 3000,
        tick_lower: -600,
        tick_upper: 600,
        liquidity: 500_000
      }

      assert {:ok, pos} = PositionManager.create_position(params)
      assert pos.tick_lower == -600
      assert pos.tick_upper == 600
      assert pos.liquidity == 500_000
      assert is_binary(pos.pool_address)
    end

    test "rejects unaligned tick spacing" do
      params = %{
        token0: @usdc,
        token1: @weth,
        fee: 3000,
        tick_lower: -605,
        tick_upper: 600
      }

      assert {:error, {:tick_not_spaced, :lower, 60}} = PositionManager.create_position(params)
    end
  end

  describe "in_range?/2" do
    test "correctly detects whether current tick falls within bounds" do
      pos = %{tick_lower: 100, tick_upper: 200}
      assert PositionManager.in_range?(pos, 150) == true
      assert PositionManager.in_range?(pos, 99) == false
      assert PositionManager.in_range?(pos, 200) == false
    end
  end

  describe "decrease_liquidity/3 and collect_fees/1" do
    test "decreases liquidity and accumulates tokens owed" do
      {:ok, pos} =
        PositionManager.create_position(%{
          token0: @usdc,
          token1: @weth,
          fee: 3000,
          tick_lower: -600,
          tick_upper: 600,
          liquidity: 1_000_000
        })

      sqrt_curr = Math.tick_to_sqrt_price_x96(0)

      assert {:ok, updated, amounts} = PositionManager.decrease_liquidity(pos, 500_000, sqrt_curr)
      assert updated.liquidity == 500_000
      assert amounts.amount0 > 0
      assert amounts.amount1 > 0
      assert updated.tokens_owed0 > 0

      {cleared_pos, collected} = PositionManager.collect_fees(updated)
      assert cleared_pos.tokens_owed0 == 0
      assert collected.collected0 > 0
    end
  end
end
