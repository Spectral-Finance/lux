defmodule Lux.Prisms.PancakeSwap.PancakeSwapRemoveLiquidityPrismTest do
  @moduledoc """
  Test suite for PancakeSwapRemoveLiquidityPrism.
  """

  use UnitCase, async: true

  alias Lux.Prisms.PancakeSwap.PancakeSwapRemoveLiquidityPrism

  @cake_token "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82"
  @usdt_token "0x55d398326f99059fF775485246999027B3197955"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "handler/2" do
    test "returns config error when keys missing" do
      System.delete_env("PANCAKESWAP_PRIVATE_KEY")
      System.delete_env("PANCAKESWAP_RPC_URL")

      assert {:error, _} = PancakeSwapRemoveLiquidityPrism.handler(
        %{
          token_a: @cake_token,
          token_b: @usdt_token,
          lp_amount: "500000000000000000000"
        },
        @agent_ctx
      )
    end

    test "accepts slippage_bps" do
      assert {:error, _} = PancakeSwapRemoveLiquidityPrism.handler(
        %{
          token_a: @cake_token,
          token_b: @usdt_token,
          lp_amount: "500000000000000000000",
          slippage_bps: 100
        },
        @agent_ctx
      )
    end

    test "accepts custom router" do
      assert {:error, _} = PancakeSwapRemoveLiquidityPrism.handler(
        %{
          token_a: @cake_token,
          token_b: @usdt_token,
          lp_amount: "100000000000000000000",
          router_address: "0x10ED43C718714eb63d5aA57B78B54704E256024E"
        },
        @agent_ctx
      )
    end
  end

  describe "prism metadata" do
    test "has correct name" do
      assert PancakeSwapRemoveLiquidityPrism.__prism__(:name) == "PancakeSwap Remove Liquidity"
    end

    test "requires token_a, token_b, lp_amount" do
      schema = PancakeSwapRemoveLiquidityPrism.__prism__(:input_schema)
      assert "token_a" in schema.required
      assert "token_b" in schema.required
      assert "lp_amount" in schema.required
    end

    test "output includes amount_a_received and amount_b_received" do
      schema = PancakeSwapRemoveLiquidityPrism.__prism__(:output_schema)
      assert Map.has_key?(schema.properties, :amount_a_received)
      assert Map.has_key?(schema.properties, :amount_b_received)
      assert Map.has_key?(schema.properties, :tx_hash)
    end
  end
end
