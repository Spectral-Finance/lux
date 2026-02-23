defmodule Lux.Prisms.Curve.CurveRemoveLiquidityPrismTest do
  @moduledoc """
  Test suite for CurveRemoveLiquidityPrism.
  """

  use UnitCase, async: true

  alias Lux.Prisms.Curve.CurveRemoveLiquidityPrism

  @pool_3crv "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7"
  @lp_amount "500000000000000000000"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "handler/2 — balanced withdrawal" do
    test "returns error when config missing" do
      System.delete_env("CURVE_PRIVATE_KEY")
      System.delete_env("CURVE_RPC_URL")

      assert {:error, reason} = CurveRemoveLiquidityPrism.handler(
        %{pool_address: @pool_3crv, lp_token_amount: @lp_amount},
        @agent_ctx
      )

      assert is_binary(reason)
    end

    test "accepts min_amounts for slippage protection" do
      assert {:error, _} = CurveRemoveLiquidityPrism.handler(
        %{
          pool_address: @pool_3crv,
          lp_token_amount: @lp_amount,
          min_amounts: ["490000000000000000000", "0", "0"]
        },
        @agent_ctx
      )
    end
  end

  describe "handler/2 — single-coin withdrawal" do
    test "accepts coin_index for single-token withdrawal" do
      assert {:error, _} = CurveRemoveLiquidityPrism.handler(
        %{
          pool_address: @pool_3crv,
          lp_token_amount: @lp_amount,
          coin_index: 1,
          min_amount: "490000000"
        },
        @agent_ctx
      )
    end

    test "accepts coin_index 0 (DAI withdrawal)" do
      assert {:error, _} = CurveRemoveLiquidityPrism.handler(
        %{
          pool_address: @pool_3crv,
          lp_token_amount: @lp_amount,
          coin_index: 0,
          min_amount: "0"
        },
        @agent_ctx
      )
    end
  end

  describe "prism metadata" do
    test "has correct name" do
      assert CurveRemoveLiquidityPrism.__prism__(:name) == "Curve Remove Liquidity"
    end

    test "requires pool_address and lp_token_amount" do
      schema = CurveRemoveLiquidityPrism.__prism__(:input_schema)
      assert "pool_address" in schema.required
      assert "lp_token_amount" in schema.required
    end

    test "output schema has amounts_received" do
      schema = CurveRemoveLiquidityPrism.__prism__(:output_schema)
      assert Map.has_key?(schema.properties, :amounts_received)
      assert Map.has_key?(schema.properties, :tx_hash)
    end
  end
end
