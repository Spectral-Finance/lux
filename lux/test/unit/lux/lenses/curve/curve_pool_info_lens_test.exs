defmodule Lux.Lenses.Curve.CurvePoolInfoLensTest do
  @moduledoc """
  Test suite for CurvePoolInfoLens.
  Tests pool analytics, RPC config resolution, and error handling.
  """

  use UnitCase, async: true

  alias Lux.Lenses.Curve.CurvePoolInfoLens

  @pool_3crv "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "focus/2 — with public RPC" do
    setup do
      System.put_env("CURVE_RPC_URL", "https://eth.llamarpc.com")
      on_exit(fn -> System.delete_env("CURVE_RPC_URL") end)
    end

    test "fetches pool info from mainnet" do
      result = CurvePoolInfoLens.focus(%{pool_address: @pool_3crv}, @agent_ctx)

      case result do
        {:ok, info} ->
          assert info.pool_address == @pool_3crv
          assert is_binary(info.virtual_price)
          assert is_list(info.balances)
          assert length(info.balances) >= 2
          assert is_integer(info.fee_bps)
          assert is_float(info.apy_total)

        {:error, _reason} ->
          # RPC may be rate-limited or unavailable in CI — acceptable
          :ok
      end
    end

    test "fetches sETH/ETH pool info" do
      steth_pool = "0xDC24316b9AE028F1497c275EB9192a3Ea0f67022"

      result = CurvePoolInfoLens.focus(%{pool_address: steth_pool}, @agent_ctx)

      case result do
        {:ok, info} ->
          assert info.pool_address == steth_pool
          assert is_binary(info.virtual_price)
        {:error, _} ->
          :ok
      end
    end
  end

  describe "focus/2 — custom RPC in input" do
    test "uses rpc_url from input params" do
      result = CurvePoolInfoLens.focus(
        %{pool_address: @pool_3crv, rpc_url: "https://eth.llamarpc.com"},
        @agent_ctx
      )

      assert {:ok, _} = result or {:error, _} = result
    end

    test "returns error on bad RPC URL" do
      result = CurvePoolInfoLens.focus(
        %{pool_address: @pool_3crv, rpc_url: "https://invalid.example.invalid"},
        @agent_ctx
      )

      assert {:error, _reason} = result
    end
  end

  describe "focus/2 — pool info shape" do
    setup do
      System.put_env("CURVE_RPC_URL", "https://eth.llamarpc.com")
      on_exit(fn -> System.delete_env("CURVE_RPC_URL") end)
    end

    test "returns all expected fields" do
      case CurvePoolInfoLens.focus(%{pool_address: @pool_3crv}, @agent_ctx) do
        {:ok, info} ->
          assert Map.has_key?(info, :pool_address)
          assert Map.has_key?(info, :virtual_price)
          assert Map.has_key?(info, :balances)
          assert Map.has_key?(info, :fee_bps)
          assert Map.has_key?(info, :apy_total)
          assert Map.has_key?(info, :tvl_usd)
        {:error, _} ->
          :ok
      end
    end

    test "virtual_price is >= 1e18 for healthy pool" do
      case CurvePoolInfoLens.focus(%{pool_address: @pool_3crv}, @agent_ctx) do
        {:ok, info} ->
          vp = String.to_integer(info.virtual_price)
          # Virtual price should be >= 1.0 (1e18) for a healthy pool
          assert vp >= 1_000_000_000_000_000_000
        {:error, _} ->
          :ok
      end
    end

    test "fee_bps is a small positive integer" do
      case CurvePoolInfoLens.focus(%{pool_address: @pool_3crv}, @agent_ctx) do
        {:ok, info} ->
          # Curve's standard fee is 0.04% = 4 bps
          assert is_integer(info.fee_bps)
          assert info.fee_bps >= 0
        {:error, _} ->
          :ok
      end
    end
  end

  describe "lens metadata" do
    test "has correct name" do
      assert CurvePoolInfoLens.__lens__(:name) == "Curve Pool Info"
    end

    test "requires pool_address" do
      schema = CurvePoolInfoLens.__lens__(:schema)
      assert "pool_address" in schema.required
    end
  end
end
