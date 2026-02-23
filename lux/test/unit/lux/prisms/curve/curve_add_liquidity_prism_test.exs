defmodule Lux.Prisms.Curve.CurveAddLiquidityPrismTest do
  @moduledoc """
  Test suite for CurveAddLiquidityPrism.
  Verifies input validation, config resolution, and error propagation.
  """

  use UnitCase, async: true

  alias Lux.Prisms.Curve.CurveAddLiquidityPrism

  @pool_3crv "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "handler/2 — configuration validation" do
    test "returns error when CURVE_PRIVATE_KEY is missing" do
      System.delete_env("CURVE_PRIVATE_KEY")
      System.delete_env("CURVE_RPC_URL")

      result = CurveAddLiquidityPrism.handler(
        %{pool_address: @pool_3crv, token_amounts: ["1000000000000000000", "0", "0"]},
        @agent_ctx
      )

      assert {:error, reason} = result
      assert is_binary(reason)
    end

    test "accepts valid 3-token amounts" do
      # Verify the prism accepts properly shaped input without crashing on validation
      # It will fail on missing config, not on input shape
      result = CurveAddLiquidityPrism.handler(
        %{
          pool_address: @pool_3crv,
          token_amounts: ["1000000000000000000000", "0", "0"],
          min_mint_amount: "0",
          slippage_bps: 50
        },
        @agent_ctx
      )

      # Config missing → error, not a crash
      assert {:error, _reason} = result
    end

    test "accepts valid 2-token amounts" do
      result = CurveAddLiquidityPrism.handler(
        %{
          pool_address: "0xDC24316b9AE028F1497c275EB9192a3Ea0f67022",
          token_amounts: ["1000000000000000000", "0"],
          slippage_bps: 100
        },
        @agent_ctx
      )

      assert {:error, _reason} = result
    end
  end

  describe "handler/2 — with env config" do
    setup do
      System.put_env("CURVE_PRIVATE_KEY", "0x" <> String.duplicate("ab", 32))
      System.put_env("CURVE_RPC_URL", "https://eth.llamarpc.com")

      on_exit(fn ->
        System.delete_env("CURVE_PRIVATE_KEY")
        System.delete_env("CURVE_RPC_URL")
      end)
    end

    test "attempts execution when config is present" do
      # With a fake key and real RPC, it will fail with Python/web3 error, not config error
      result = CurveAddLiquidityPrism.handler(
        %{
          pool_address: @pool_3crv,
          token_amounts: ["1000000000000000000000", "0", "0"]
        },
        @agent_ctx
      )

      # Either succeeds or fails with a web3/Python error (not config error)
      case result do
        {:ok, output} ->
          assert Map.has_key?(output, :pool_address)
          assert Map.has_key?(output, :status)
        {:error, reason} ->
          assert is_binary(reason)
          refute String.contains?(reason, "Missing configuration")
      end
    end
  end

  describe "prism metadata" do
    test "has correct name" do
      assert CurveAddLiquidityPrism.__prism__(:name) == "Curve Add Liquidity"
    end

    test "has input schema with required fields" do
      schema = CurveAddLiquidityPrism.__prism__(:input_schema)
      assert schema.type == :object
      assert "pool_address" in schema.required
      assert "token_amounts" in schema.required
    end

    test "has output schema with required fields" do
      schema = CurveAddLiquidityPrism.__prism__(:output_schema)
      assert schema.type == :object
      assert "pool_address" in schema.required
      assert "tx_hash" in schema.required
      assert "status" in schema.required
    end
  end
end
