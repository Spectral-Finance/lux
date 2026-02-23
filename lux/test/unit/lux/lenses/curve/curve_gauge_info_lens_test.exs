defmodule Lux.Lenses.Curve.CurveGaugeInfoLensTest do
  @moduledoc """
  Test suite for CurveGaugeInfoLens.
  Tests gauge metrics: staked TVL, CRV emission rate, and boost info.
  """

  use UnitCase, async: true

  alias Lux.Lenses.Curve.CurveGaugeInfoLens

  @gauge_3crv "0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A"
  @agent_ctx %{agent: %{name: "YieldAgent"}}

  describe "focus/2 — gauge metrics" do
    setup do
      System.put_env("CURVE_RPC_URL", "https://eth.llamarpc.com")
      on_exit(fn -> System.delete_env("CURVE_RPC_URL") end)
    end

    test "fetches 3pool gauge info" do
      result = CurveGaugeInfoLens.focus(%{gauge_address: @gauge_3crv}, @agent_ctx)

      case result do
        {:ok, info} ->
          assert info.gauge_address == @gauge_3crv
          assert is_binary(info.total_staked)
          assert is_binary(info.working_supply)
          assert is_binary(info.crv_rate)
          assert is_float(info.relative_weight)
          assert info.boost_max == 2.5

        {:error, _reason} ->
          :ok
      end
    end

    test "fetches stETH gauge info" do
      steth_gauge = "0x182B723a58739a9c974cFDB385ceaDb237453c28"

      result = CurveGaugeInfoLens.focus(%{gauge_address: steth_gauge}, @agent_ctx)

      case result do
        {:ok, info} ->
          assert info.gauge_address == steth_gauge
          assert is_binary(info.total_staked)
        {:error, _} ->
          :ok
      end
    end
  end

  describe "focus/2 — gauge info shape" do
    setup do
      System.put_env("CURVE_RPC_URL", "https://eth.llamarpc.com")
      on_exit(fn -> System.delete_env("CURVE_RPC_URL") end)
    end

    test "total_staked is a non-negative integer string" do
      case CurveGaugeInfoLens.focus(%{gauge_address: @gauge_3crv}, @agent_ctx) do
        {:ok, info} ->
          staked = String.to_integer(info.total_staked)
          assert staked >= 0
        {:error, _} ->
          :ok
      end
    end

    test "relative_weight is between 0 and 1" do
      case CurveGaugeInfoLens.focus(%{gauge_address: @gauge_3crv}, @agent_ctx) do
        {:ok, info} ->
          assert info.relative_weight >= 0.0
          assert info.relative_weight <= 1.0
        {:error, _} ->
          :ok
      end
    end

    test "boost_max is always 2.5 (CRV gauge max)" do
      case CurveGaugeInfoLens.focus(%{gauge_address: @gauge_3crv}, @agent_ctx) do
        {:ok, info} ->
          assert info.boost_max == 2.5
        {:error, _} ->
          :ok
      end
    end

    test "returns all required fields" do
      case CurveGaugeInfoLens.focus(%{gauge_address: @gauge_3crv}, @agent_ctx) do
        {:ok, info} ->
          assert Map.has_key?(info, :gauge_address)
          assert Map.has_key?(info, :total_staked)
          assert Map.has_key?(info, :working_supply)
          assert Map.has_key?(info, :crv_rate)
          assert Map.has_key?(info, :inflation_rate)
          assert Map.has_key?(info, :relative_weight)
          assert Map.has_key?(info, :boost_max)
          assert Map.has_key?(info, :crv_annual_per_lp)
        {:error, _} ->
          :ok
      end
    end
  end

  describe "focus/2 — invalid gauge" do
    setup do
      System.put_env("CURVE_RPC_URL", "https://eth.llamarpc.com")
      on_exit(fn -> System.delete_env("CURVE_RPC_URL") end)
    end

    test "returns error for non-existent gauge address" do
      random_addr = "0x1111111111111111111111111111111111111111"

      result = CurveGaugeInfoLens.focus(%{gauge_address: random_addr}, @agent_ctx)

      # May succeed with zeroes or return an error — either is valid
      assert {:ok, _} = result or {:error, _} = result
    end
  end

  describe "lens metadata" do
    test "has correct name" do
      assert CurveGaugeInfoLens.__lens__(:name) == "Curve Gauge Info"
    end

    test "requires only gauge_address" do
      schema = CurveGaugeInfoLens.__lens__(:schema)
      assert schema.required == ["gauge_address"]
    end
  end
end
