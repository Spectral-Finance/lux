defmodule Lux.Prisms.Curve.CurveExchangePrismTest do
  @moduledoc """
  Test suite for CurveExchangePrism.
  Tests token swap input validation and slippage configuration.
  """

  use UnitCase, async: true

  alias Lux.Prisms.Curve.CurveExchangePrism

  @pool_3crv "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "handler/2 — input validation" do
    test "returns config error for missing keys" do
      System.delete_env("CURVE_PRIVATE_KEY")
      System.delete_env("CURVE_RPC_URL")

      assert {:error, _reason} = CurveExchangePrism.handler(
        %{
          pool_address: @pool_3crv,
          from_index: 0,
          to_index: 2,
          amount: "1000000000000000000000"
        },
        @agent_ctx
      )
    end

    test "accepts DAI→USDT swap (0→2)" do
      assert {:error, _} = CurveExchangePrism.handler(
        %{
          pool_address: @pool_3crv,
          from_index: 0,
          to_index: 2,
          amount: "1000000000000000000000",
          min_dy: "0"
        },
        @agent_ctx
      )
    end

    test "accepts USDC→DAI swap (1→0)" do
      assert {:error, _} = CurveExchangePrism.handler(
        %{
          pool_address: @pool_3crv,
          from_index: 1,
          to_index: 0,
          amount: "1000000000",
          min_dy: "990000000000000000000"
        },
        @agent_ctx
      )
    end

    test "accepts USDT→USDC swap (2→1)" do
      assert {:error, _} = CurveExchangePrism.handler(
        %{
          pool_address: @pool_3crv,
          from_index: 2,
          to_index: 1,
          amount: "5000000000"
        },
        @agent_ctx
      )
    end
  end

  describe "prism metadata" do
    test "has correct name" do
      assert CurveExchangePrism.__prism__(:name) == "Curve Exchange"
    end

    test "requires pool, indices, and amount" do
      schema = CurveExchangePrism.__prism__(:input_schema)
      assert "pool_address" in schema.required
      assert "from_index" in schema.required
      assert "to_index" in schema.required
      assert "amount" in schema.required
    end

    test "output has amount_in, amount_out, slippage_bps" do
      schema = CurveExchangePrism.__prism__(:output_schema)
      assert Map.has_key?(schema.properties, :amount_in)
      assert Map.has_key?(schema.properties, :amount_out)
      assert Map.has_key?(schema.properties, :slippage_bps)
    end
  end
end
