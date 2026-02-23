defmodule Lux.Prisms.Curve.CurveStakeGaugePrismTest do
  @moduledoc """
  Test suite for CurveStakeGaugePrism.
  Tests stake/unstake actions, config validation, and schema.
  """

  use UnitCase, async: true

  alias Lux.Prisms.Curve.CurveStakeGaugePrism

  @gauge_3crv "0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A"
  @lp_amount "1000000000000000000000"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "handler/2 — stake action" do
    test "returns config error when keys missing" do
      System.delete_env("CURVE_PRIVATE_KEY")
      System.delete_env("CURVE_RPC_URL")

      assert {:error, _reason} = CurveStakeGaugePrism.handler(
        %{gauge_address: @gauge_3crv, amount: @lp_amount, action: "stake"},
        @agent_ctx
      )
    end

    test "accepts optional lp_token_address for approval" do
      assert {:error, _} = CurveStakeGaugePrism.handler(
        %{
          gauge_address: @gauge_3crv,
          amount: @lp_amount,
          action: "stake",
          lp_token_address: "0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490"
        },
        @agent_ctx
      )
    end
  end

  describe "handler/2 — unstake action" do
    test "returns config error when keys missing" do
      System.delete_env("CURVE_PRIVATE_KEY")
      System.delete_env("CURVE_RPC_URL")

      assert {:error, _reason} = CurveStakeGaugePrism.handler(
        %{gauge_address: @gauge_3crv, amount: @lp_amount, action: "unstake"},
        @agent_ctx
      )
    end
  end

  describe "prism metadata" do
    test "has correct name and description" do
      assert CurveStakeGaugePrism.__prism__(:name) == "Curve Stake Gauge"
      assert is_binary(CurveStakeGaugePrism.__prism__(:description))
    end

    test "action is required in input schema" do
      schema = CurveStakeGaugePrism.__prism__(:input_schema)
      assert "action" in schema.required
      assert "gauge_address" in schema.required
      assert "amount" in schema.required
    end

    test "action enum accepts stake and unstake" do
      schema = CurveStakeGaugePrism.__prism__(:input_schema)
      action_schema = schema.properties.action
      assert "stake" in action_schema.enum
      assert "unstake" in action_schema.enum
    end

    test "output includes status field" do
      schema = CurveStakeGaugePrism.__prism__(:output_schema)
      assert Map.has_key?(schema.properties, :status)
      assert Map.has_key?(schema.properties, :tx_hash)
    end
  end
end
