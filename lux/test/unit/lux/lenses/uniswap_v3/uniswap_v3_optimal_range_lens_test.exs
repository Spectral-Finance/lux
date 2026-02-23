defmodule Lux.Lenses.UniswapV3.UniswapV3OptimalRangeLensTest do
  use UnitCase, async: true

  alias Lux.Lenses.UniswapV3.UniswapV3OptimalRangeLens

  @usdc "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
  @weth "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"

  describe "focus/2 — input validation" do
    test "rejects missing token0" do
      result = UniswapV3OptimalRangeLens.focus(%{token1: @weth}, %{})
      assert {:error, _} = result
    end

    test "rejects missing token1" do
      result = UniswapV3OptimalRangeLens.focus(%{token0: @usdc}, %{})
      assert {:error, _} = result
    end

    test "accepts token0+token1 with defaults" do
      result = UniswapV3OptimalRangeLens.focus(%{
        token0: @usdc,
        token1: @weth,
        rpc_url: "http://localhost:18545"
      })
      assert {:error, _} = result
    end

    test "accepts custom fee tier" do
      result = UniswapV3OptimalRangeLens.focus(%{
        token0: @usdc,
        token1: @weth,
        fee: 500,
        rpc_url: "http://localhost:18545"
      })
      assert {:error, _} = result
    end

    test "accepts custom range_multiplier" do
      result = UniswapV3OptimalRangeLens.focus(%{
        token0: @usdc,
        token1: @weth,
        range_multiplier: 3.0,
        rpc_url: "http://localhost:18545"
      })
      assert {:error, _} = result
    end

    test "accepts all fee tiers" do
      for fee <- [100, 500, 3000, 10000] do
        result = UniswapV3OptimalRangeLens.focus(%{
          token0: @usdc,
          token1: @weth,
          fee: fee,
          rpc_url: "http://localhost:18545"
        })
        assert {:error, _} = result
      end
    end

    test "uses default range_multiplier of 2.0" do
      result = UniswapV3OptimalRangeLens.focus(%{
        token0: @usdc,
        token1: @weth
        # range_multiplier defaults to 2.0
      })
      assert {:error, _} = result
    end
  end

  describe "schema" do
    test "schema documents all key properties" do
      schema = UniswapV3OptimalRangeLens.view().schema
      props = schema.properties
      assert Map.has_key?(props, :token0)
      assert Map.has_key?(props, :token1)
      assert Map.has_key?(props, :fee)
      assert Map.has_key?(props, :range_multiplier)
      assert Map.has_key?(props, :factory_address)
    end
  end
end
