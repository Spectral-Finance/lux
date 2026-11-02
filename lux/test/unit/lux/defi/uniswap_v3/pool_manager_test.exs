defmodule Lux.Defi.UniswapV3.PoolManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Defi.UniswapV3.PoolManager

  @weth "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
  @usdc "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"

  describe "sort_tokens/2" do
    test "orders tokens lexicographically" do
      assert {:ok, {@usdc, @weth}} = PoolManager.sort_tokens(@weth, @usdc)
      assert {:ok, {@usdc, @weth}} = PoolManager.sort_tokens(@usdc, @weth)
    end

    test "rejects identical tokens" do
      assert {:error, :identical_tokens} = PoolManager.sort_tokens(@weth, @weth)
    end
  end

  describe "tick_spacing_for_fee/1" do
    test "maps fee tiers to standard tick spacings" do
      assert PoolManager.tick_spacing_for_fee(100) == 1
      assert PoolManager.tick_spacing_for_fee(500) == 10
      assert PoolManager.tick_spacing_for_fee(3000) == 60
      assert PoolManager.tick_spacing_for_fee(10000) == 200
    end
  end

  describe "compute_pool_address/4" do
    test "generates deterministic CREATE2 pool address" do
      assert {:ok, addr} = PoolManager.compute_pool_address(@weth, @usdc, 3000)
      assert String.starts_with?(addr, "0x")
      assert String.length(addr) == 42
    end
  end

  describe "recommend_fee_tier/1" do
    test "recommends fee tiers by asset class" do
      assert PoolManager.recommend_fee_tier(:stable) == 100
      assert PoolManager.recommend_fee_tier(:correlated) == 500
      assert PoolManager.recommend_fee_tier(:standard) == 3000
      assert PoolManager.recommend_fee_tier(:exotic) == 10000
    end
  end
end
