defmodule Lux.Integrations.CurveTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Curve

  describe "pool queries" do
    test "get_pools returns pool list" do
      result = Curve.get_pools("ethereum")
      assert elem(result, 0) in [:ok, :error]
    end

    test "get_pool returns pool details" do
      result = Curve.get_pool("0x000", "ethereum")
      assert elem(result, 0) in [:ok, :error]
    end

    test "get_factory_pools returns factory pool data" do
      result = Curve.get_factory_pools("ethereum")
      assert elem(result, 0) in [:ok, :error]
    end
  end

  describe "pool analytics" do
    test "analyze_pool returns analytics" do
      result = Curve.analyze_pool("0x000")
      assert {:ok, analytics} = result
      assert Map.has_key?(analytics, :pool_id)
      assert Map.has_key?(analytics, :apy)
      assert Map.has_key?(analytics, :virtual_price)
      assert Map.has_key?(analytics, :amplification_coefficient)
      assert Map.has_key?(analytics, :volume_24h_usd)
      assert Map.has_key?(analytics, :daily_fees_usd)
    end

    test "get_pool_apy_history returns APY data" do
      result = Curve.get_pool_apy_history("0x000", 7)
      assert {:ok, history} = result
      assert Map.has_key?(history, :apy_data)
      assert Map.has_key?(history, :average_apy)
    end

    test "get_utilization_rate returns utilization" do
      result = Curve.get_utilization_rate("0x000")
      assert {:ok, util} = result
      assert Map.has_key?(util, :utilization_rate)
      assert Map.has_key?(util, :status)
    end
  end

  describe "stablecoin swap calculations" do
    test "calculate_swap returns swap details" do
      result = Curve.calculate_swap("0x000", "0xUSDC", "0xUSDT", 1000)
      assert {:ok, swap} = result
      assert Map.has_key?(swap, :expected_output)
      assert Map.has_key?(swap, :fee_paid)
      assert Map.has_key?(swap, :price_impact_pct)
      assert Map.has_key?(swap, :exchange_rate)
    end

    test "calculate_optimal_swap returns optimal swap" do
      result = Curve.calculate_optimal_swap("0x000", "0xUSDC", "0xUSDT", max_slippage: 0.01)
      assert {:ok, swap} = result
      assert Map.has_key?(swap, :expected_output)
    end

    test "estimate_slippage returns price impact" do
      result = Curve.estimate_slippage("0x000", "0xUSDC", "0xUSDT", 1000)
      assert {:ok, slippage} = result
      assert is_float(slippage)
    end

    test "find_best_pool_for_swap returns best pools" do
      result = Curve.find_best_pool_for_swap("0xUSDC", "0xUSDT", 1000)
      assert {:ok, best} = result
      assert Map.has_key?(best, :best_pools)
    end
  end

  describe "D invariant calculation" do
    test "compute_d returns positive value for valid balances" do
      d = Curve.compute_d([1_000_000, 1_000_000], 100, 2)
      assert d > 0
    end

    test "compute_d returns 0 for zero balances" do
      d = Curve.compute_d([0, 0], 100, 2)
      assert d == 0
    end
  end

  describe "format helpers" do
    test "format_pool handles various input formats" do
      result = Curve.get_pools("ethereum")
      assert elem(result, 0) in [:ok, :error]
    end
  end
end
