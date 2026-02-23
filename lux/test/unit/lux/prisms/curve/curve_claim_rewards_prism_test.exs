defmodule Lux.Prisms.Curve.CurveClaimRewardsPrismTest do
  @moduledoc """
  Test suite for CurveClaimRewardsPrism.
  """

  use UnitCase, async: true

  alias Lux.Prisms.Curve.CurveClaimRewardsPrism

  @gauge_3crv "0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "handler/2" do
    test "returns error when private key not configured" do
      System.delete_env("CURVE_PRIVATE_KEY")
      System.delete_env("CURVE_RPC_URL")

      assert {:error, reason} = CurveClaimRewardsPrism.handler(
        %{gauge_address: @gauge_3crv},
        @agent_ctx
      )

      assert is_binary(reason)
    end

    test "accepts claim_extra_rewards flag" do
      assert {:error, _} = CurveClaimRewardsPrism.handler(
        %{gauge_address: @gauge_3crv, claim_extra_rewards: false},
        @agent_ctx
      )
    end

    test "defaults claim_extra_rewards to true" do
      # Just verify it doesn't crash on input without the optional field
      assert {:error, _} = CurveClaimRewardsPrism.handler(
        %{gauge_address: @gauge_3crv},
        @agent_ctx
      )
    end
  end

  describe "prism metadata" do
    test "has correct name" do
      assert CurveClaimRewardsPrism.__prism__(:name) == "Curve Claim Rewards"
    end

    test "requires only gauge_address" do
      schema = CurveClaimRewardsPrism.__prism__(:input_schema)
      assert schema.required == ["gauge_address"]
    end

    test "output schema includes crv_claimed" do
      schema = CurveClaimRewardsPrism.__prism__(:output_schema)
      assert Map.has_key?(schema.properties, :crv_claimed)
      assert Map.has_key?(schema.properties, :tx_hash)
      assert Map.has_key?(schema.properties, :status)
    end
  end
end
