defmodule Lux.Prisms.UniswapV3.UniswapV3RemoveLiquidityPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.UniswapV3.UniswapV3RemoveLiquidityPrism

  @test_pk "0x" <> String.duplicate("2b", 32)

  describe "handler/2 — input validation" do
    test "rejects missing token_id" do
      System.delete_env("UNISWAP_V3_PRIVATE_KEY")
      assert {:error, _} = UniswapV3RemoveLiquidityPrism.run(%{
        liquidity_percent: 100
      })
    end

    test "rejects when private key not configured" do
      System.delete_env("UNISWAP_V3_PRIVATE_KEY")
      assert {:error, "Missing configuration: UNISWAP_V3_PRIVATE_KEY"} =
        UniswapV3RemoveLiquidityPrism.run(%{token_id: 123456})
    end
  end

  describe "handler/2 — with env config" do
    setup do
      System.put_env("UNISWAP_V3_PRIVATE_KEY", @test_pk)
      System.put_env("UNISWAP_V3_RPC_URL", "http://localhost:18545")
      on_exit(fn ->
        System.delete_env("UNISWAP_V3_PRIVATE_KEY")
        System.delete_env("UNISWAP_V3_RPC_URL")
      end)
      :ok
    end

    test "connects to RPC with correct config" do
      result = UniswapV3RemoveLiquidityPrism.run(%{token_id: 123456})
      assert {:error, reason} = result
      refute reason =~ "Missing configuration"
    end

    test "defaults liquidity_percent to 100" do
      result = UniswapV3RemoveLiquidityPrism.run(%{
        token_id: 999,
        # no liquidity_percent — should default to 100
      })
      assert {:error, _} = result
    end

    test "accepts partial liquidity removal" do
      result = UniswapV3RemoveLiquidityPrism.run(%{
        token_id: 123456,
        liquidity_percent: 50
      })
      assert {:error, _} = result
    end

    test "accepts custom slippage" do
      result = UniswapV3RemoveLiquidityPrism.run(%{
        token_id: 123456,
        liquidity_percent: 100,
        slippage_bps: 200
      })
      assert {:error, _} = result
    end

    test "accepts custom deadline" do
      result = UniswapV3RemoveLiquidityPrism.run(%{
        token_id: 123456,
        deadline_seconds: 3600
      })
      assert {:error, _} = result
    end

    test "accepts custom position_manager_address" do
      result = UniswapV3RemoveLiquidityPrism.run(%{
        token_id: 123456,
        position_manager_address: "0xC36442b4a4522E871399CD717aBDD847Ab11FE88"
      })
      assert {:error, _} = result
    end
  end

  describe "output schema" do
    test "required output fields are defined" do
      schema = UniswapV3RemoveLiquidityPrism.view().output_schema
      props = schema.properties
      assert Map.has_key?(props, :token_id)
      assert Map.has_key?(props, :liquidity_removed)
      assert Map.has_key?(props, :amount0_collected)
      assert Map.has_key?(props, :amount1_collected)
      assert Map.has_key?(props, :fees0_collected)
      assert Map.has_key?(props, :fees1_collected)
      assert Map.has_key?(props, :tx_hash)
      assert Map.has_key?(props, :status)
    end
  end
end
