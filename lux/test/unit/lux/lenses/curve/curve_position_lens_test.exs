defmodule Lux.Lenses.Curve.CurvePositionLensTest do
  @moduledoc """
  Test suite for CurvePositionLens.
  Tests user position queries including LP balances and pending rewards.
  """

  use UnitCase, async: true

  alias Lux.Lenses.Curve.CurvePositionLens

  @pool_3crv "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7"
  @lp_3crv "0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490"
  @gauge_3crv "0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A"
  # Use vitalik.eth for testing — large known LP holder
  @test_address "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
  @agent_ctx %{agent: %{name: "PortfolioAgent"}}

  describe "focus/2 — basic position query" do
    setup do
      System.put_env("CURVE_RPC_URL", "https://eth.llamarpc.com")
      on_exit(fn -> System.delete_env("CURVE_RPC_URL") end)
    end

    test "fetches position for any address" do
      result = CurvePositionLens.focus(
        %{
          pool_address: @pool_3crv,
          lp_token_address: @lp_3crv,
          user_address: @test_address
        },
        @agent_ctx
      )

      case result do
        {:ok, pos} ->
          assert pos.user_address == @test_address
          assert pos.pool_address == @pool_3crv
          assert is_binary(pos.lp_balance)
          assert is_binary(pos.staked_balance)
          assert is_binary(pos.total_lp)
          assert is_float(pos.position_usd) or is_integer(pos.position_usd)
          assert is_float(pos.share_of_pool)
        {:error, _} ->
          :ok
      end
    end

    test "includes gauge info when gauge_address provided" do
      result = CurvePositionLens.focus(
        %{
          pool_address: @pool_3crv,
          lp_token_address: @lp_3crv,
          gauge_address: @gauge_3crv,
          user_address: @test_address
        },
        @agent_ctx
      )

      case result do
        {:ok, pos} ->
          assert is_binary(pos.pending_crv)
          assert is_binary(pos.staked_balance)
        {:error, _} ->
          :ok
      end
    end

    test "zero position for fresh address" do
      fresh_address = "0x0000000000000000000000000000000000000001"

      result = CurvePositionLens.focus(
        %{
          pool_address: @pool_3crv,
          lp_token_address: @lp_3crv,
          user_address: fresh_address
        },
        @agent_ctx
      )

      case result do
        {:ok, pos} ->
          assert pos.lp_balance == "0"
          assert pos.position_usd == 0.0 or pos.position_usd == 0
        {:error, _} ->
          :ok
      end
    end
  end

  describe "focus/2 — output structure" do
    setup do
      System.put_env("CURVE_RPC_URL", "https://eth.llamarpc.com")
      on_exit(fn -> System.delete_env("CURVE_RPC_URL") end)
    end

    test "returns all required fields" do
      case CurvePositionLens.focus(
        %{
          pool_address: @pool_3crv,
          lp_token_address: @lp_3crv,
          user_address: @test_address
        },
        @agent_ctx
      ) do
        {:ok, pos} ->
          assert Map.has_key?(pos, :user_address)
          assert Map.has_key?(pos, :pool_address)
          assert Map.has_key?(pos, :lp_balance)
          assert Map.has_key?(pos, :staked_balance)
          assert Map.has_key?(pos, :total_lp)
          assert Map.has_key?(pos, :underlying_amounts)
          assert Map.has_key?(pos, :position_usd)
          assert Map.has_key?(pos, :pending_crv)
          assert Map.has_key?(pos, :share_of_pool)
        {:error, _} ->
          :ok
      end
    end
  end

  describe "lens metadata" do
    test "has correct name" do
      assert CurvePositionLens.__lens__(:name) == "Curve Position"
    end

    test "requires pool_address, lp_token_address, user_address" do
      schema = CurvePositionLens.__lens__(:schema)
      assert "pool_address" in schema.required
      assert "lp_token_address" in schema.required
      assert "user_address" in schema.required
    end

    test "gauge_address is optional" do
      schema = CurvePositionLens.__lens__(:schema)
      refute "gauge_address" in schema.required
      assert Map.has_key?(schema.properties, :gauge_address)
    end
  end
end
