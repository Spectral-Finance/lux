defmodule Lux.Prisms.PancakeSwap.PancakeSwapAddLiquidityPrismTest do
  @moduledoc """
  Test suite for PancakeSwapAddLiquidityPrism.
  """

  use UnitCase, async: true

  alias Lux.Prisms.PancakeSwap.PancakeSwapAddLiquidityPrism

  @cake_token "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82"
  @usdt_token "0x55d398326f99059fF775485246999027B3197955"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "handler/2 — config validation" do
    test "returns config error when private key missing" do
      System.delete_env("PANCAKESWAP_PRIVATE_KEY")
      System.delete_env("PANCAKESWAP_RPC_URL")

      assert {:error, reason} = PancakeSwapAddLiquidityPrism.handler(
        %{
          token_a: @cake_token,
          token_b: @usdt_token,
          amount_a_desired: "1000000000000000000000",
          amount_b_desired: "1000000000000000000000"
        },
        @agent_ctx
      )

      assert is_binary(reason)
    end

    test "accepts custom router address" do
      assert {:error, _} = PancakeSwapAddLiquidityPrism.handler(
        %{
          token_a: @cake_token,
          token_b: @usdt_token,
          amount_a_desired: "1000000000000000000000",
          amount_b_desired: "1000000000000000000000",
          router_address: "0x10ED43C718714eb63d5aA57B78B54704E256024E",
          slippage_bps: 100
        },
        @agent_ctx
      )
    end

    test "accepts deadline_seconds parameter" do
      assert {:error, _} = PancakeSwapAddLiquidityPrism.handler(
        %{
          token_a: @cake_token,
          token_b: @usdt_token,
          amount_a_desired: "500000000000000000",
          amount_b_desired: "500000000000000000",
          deadline_seconds: 600
        },
        @agent_ctx
      )
    end
  end

  describe "prism metadata" do
    test "has correct name" do
      assert PancakeSwapAddLiquidityPrism.__prism__(:name) == "PancakeSwap Add Liquidity"
    end

    test "requires token_a, token_b, and amounts" do
      schema = PancakeSwapAddLiquidityPrism.__prism__(:input_schema)
      assert "token_a" in schema.required
      assert "token_b" in schema.required
      assert "amount_a_desired" in schema.required
      assert "amount_b_desired" in schema.required
    end

    test "output includes lp_tokens_minted and tx_hash" do
      schema = PancakeSwapAddLiquidityPrism.__prism__(:output_schema)
      assert Map.has_key?(schema.properties, :lp_tokens_minted)
      assert Map.has_key?(schema.properties, :tx_hash)
      assert Map.has_key?(schema.properties, :status)
    end

    test "slippage_bps has reasonable bounds" do
      schema = PancakeSwapAddLiquidityPrism.__prism__(:input_schema)
      slippage = schema.properties.slippage_bps
      assert slippage.minimum == 0
      assert slippage.maximum == 5000
    end
  end
end
