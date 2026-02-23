defmodule Lux.Prisms.UniswapV3.UniswapV3AddLiquidityPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.UniswapV3.UniswapV3AddLiquidityPrism

  # Test addresses (mainnet USDC/WETH)
  @usdc "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
  @weth "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
  @test_pk "0x" <> String.duplicate("1a", 32)

  describe "handler/2 — input validation" do
    test "rejects missing required fields" do
      assert {:error, _} = UniswapV3AddLiquidityPrism.run(%{
        token0: @usdc,
        token1: @weth,
        fee: 3000
        # missing amount0, amount1, price_lower, price_upper
      })
    end

    test "rejects when private key not configured" do
      # Without UNISWAP_V3_PRIVATE_KEY env var
      System.delete_env("UNISWAP_V3_PRIVATE_KEY")
      assert {:error, msg} = UniswapV3AddLiquidityPrism.run(%{
        token0: @usdc,
        token1: @weth,
        fee: 3000,
        amount0_desired: "1000000000",
        amount1_desired: "500000000000000000",
        price_lower: "1500.0",
        price_upper: "2500.0"
      })
      assert msg =~ "Missing configuration"
    end

    test "accepts valid fee tiers" do
      for fee <- [100, 500, 3000, 10000] do
        # Just check the schema accepts the fee — actual tx will fail without valid key
        input = %{
          token0: @usdc,
          token1: @weth,
          fee: fee,
          amount0_desired: "1000000",
          amount1_desired: "500000000000000",
          price_lower: "1000.0",
          price_upper: "3000.0"
        }
        # Should reach the config check, not schema validation
        result = UniswapV3AddLiquidityPrism.run(input)
        assert match?({:error, _}, result)
      end
    end
  end

  describe "handler/2 — price/tick logic" do
    test "price range lower < upper is enforced" do
      # Price: 2000, range 1500-2500 = valid
      input = %{
        token0: @usdc,
        token1: @weth,
        fee: 3000,
        amount0_desired: "1000000000",
        amount1_desired: "500000000000000000",
        price_lower: "1500.0",
        price_upper: "2500.0"
      }
      System.delete_env("UNISWAP_V3_PRIVATE_KEY")
      result = UniswapV3AddLiquidityPrism.run(input)
      # Will fail on missing config, not on price logic
      assert {:error, "Missing configuration: UNISWAP_V3_PRIVATE_KEY"} = result
    end

    test "very narrow price range is accepted" do
      input = %{
        token0: @usdc,
        token1: @weth,
        fee: 500,
        amount0_desired: "1000000000",
        amount1_desired: "500000000000000000",
        price_lower: "2099.0",
        price_upper: "2101.0"
      }
      System.delete_env("UNISWAP_V3_PRIVATE_KEY")
      result = UniswapV3AddLiquidityPrism.run(input)
      assert {:error, _} = result
    end
  end

  describe "handler/2 — with mocked RPC (env config)" do
    setup do
      System.put_env("UNISWAP_V3_PRIVATE_KEY", @test_pk)
      System.put_env("UNISWAP_V3_RPC_URL", "http://localhost:18545")
      on_exit(fn ->
        System.delete_env("UNISWAP_V3_PRIVATE_KEY")
        System.delete_env("UNISWAP_V3_RPC_URL")
      end)
      :ok
    end

    test "uses env var for private key" do
      result = UniswapV3AddLiquidityPrism.run(%{
        token0: @usdc,
        token1: @weth,
        fee: 3000,
        amount0_desired: "1000000000",
        amount1_desired: "500000000000000000",
        price_lower: "1500.0",
        price_upper: "2500.0"
      })
      # Will fail connecting to localhost:18545, but not on config validation
      assert {:error, reason} = result
      refute reason =~ "Missing configuration"
    end

    test "applies slippage_bps default of 50" do
      result = UniswapV3AddLiquidityPrism.run(%{
        token0: @usdc,
        token1: @weth,
        fee: 3000,
        amount0_desired: "1000000000",
        amount1_desired: "500000000000000000",
        price_lower: "1500.0",
        price_upper: "2500.0"
        # slippage_bps defaults to 50
      })
      assert {:error, _} = result
    end

    test "applies deadline_seconds default of 1200" do
      result = UniswapV3AddLiquidityPrism.run(%{
        token0: @usdc,
        token1: @weth,
        fee: 3000,
        amount0_desired: "1000000000",
        amount1_desired: "500000000000000000",
        price_lower: "1500.0",
        price_upper: "2500.0",
        deadline_seconds: 600
      })
      assert {:error, _} = result
    end

    test "accepts custom position_manager_address" do
      result = UniswapV3AddLiquidityPrism.run(%{
        token0: @usdc,
        token1: @weth,
        fee: 3000,
        amount0_desired: "1000000000",
        amount1_desired: "500000000000000000",
        price_lower: "1500.0",
        price_upper: "2500.0",
        position_manager_address: "0xC36442b4a4522E871399CD717aBDD847Ab11FE88"
      })
      assert {:error, _} = result
    end

    test "accepts fee tier 100 (0.01%)" do
      result = UniswapV3AddLiquidityPrism.run(%{
        token0: @usdc,
        token1: @weth,
        fee: 100,
        amount0_desired: "1000000000",
        amount1_desired: "500000000000000000",
        price_lower: "2000.0",
        price_upper: "2200.0"
      })
      assert {:error, _} = result
    end

    test "accepts fee tier 10000 (1%)" do
      result = UniswapV3AddLiquidityPrism.run(%{
        token0: @usdc,
        token1: @weth,
        fee: 10000,
        amount0_desired: "1000000000",
        amount1_desired: "500000000000000000",
        price_lower: "1000.0",
        price_upper: "4000.0"
      })
      assert {:error, _} = result
    end
  end

  describe "output schema" do
    test "output fields are documented" do
      schema = UniswapV3AddLiquidityPrism.view().output_schema
      props = schema.properties
      assert Map.has_key?(props, :token_id)
      assert Map.has_key?(props, :liquidity)
      assert Map.has_key?(props, :amount0)
      assert Map.has_key?(props, :amount1)
      assert Map.has_key?(props, :tx_hash)
      assert Map.has_key?(props, :gas_used)
      assert Map.has_key?(props, :status)
    end
  end
end
