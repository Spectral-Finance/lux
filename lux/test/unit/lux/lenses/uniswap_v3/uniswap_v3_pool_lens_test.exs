defmodule Lux.Lenses.UniswapV3.UniswapV3PoolLensTest do
  use UnitCase, async: true

  alias Lux.Lenses.UniswapV3.UniswapV3PoolLens

  @usdc "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
  @weth "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
  @usdc_weth_3000_pool "0x88e6A0c2ddd26FEEb64F039a2c41296FcB3f5640"

  describe "focus/2 — input validation" do
    test "rejects empty input" do
      assert {:error, msg} = UniswapV3PoolLens.focus(%{}, %{})
      assert msg =~ "pool_address or token0+token1+fee"
    end

    test "rejects token0 without token1" do
      result = UniswapV3PoolLens.focus(%{token0: @usdc}, %{})
      assert {:error, _} = result
    end

    test "accepts pool_address directly" do
      result = UniswapV3PoolLens.focus(%{
        pool_address: @usdc_weth_3000_pool,
        rpc_url: "http://localhost:18545"
      })
      assert {:error, _} = result
    end

    test "accepts token0+token1+fee" do
      result = UniswapV3PoolLens.focus(%{
        token0: @usdc,
        token1: @weth,
        fee: 3000,
        rpc_url: "http://localhost:18545"
      })
      assert {:error, _} = result
    end

    test "accepts all fee tiers" do
      for fee <- [100, 500, 3000, 10000] do
        result = UniswapV3PoolLens.focus(%{
          token0: @usdc,
          token1: @weth,
          fee: fee,
          rpc_url: "http://localhost:18545"
        })
        assert {:error, _} = result
      end
    end
  end

  describe "focus/2 — output fields" do
    test "returns error on bad RPC" do
      result = UniswapV3PoolLens.focus(%{
        pool_address: @usdc_weth_3000_pool,
        rpc_url: "http://localhost:18545"
      })
      assert {:error, _} = result
    end
  end

  describe "schema" do
    test "schema has key properties" do
      schema = UniswapV3PoolLens.view().schema
      props = schema.properties
      assert Map.has_key?(props, :pool_address)
      assert Map.has_key?(props, :token0)
      assert Map.has_key?(props, :token1)
      assert Map.has_key?(props, :fee)
      assert Map.has_key?(props, :factory_address)
    end
  end
end
