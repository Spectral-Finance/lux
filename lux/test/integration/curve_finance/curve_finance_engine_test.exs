defmodule Lux.Integration.CurveFinanceEngineTest do
  use ExUnit.Case, async: false

  alias Lux.Beams.CurveFinanceEngine

  describe "run/1 - action: analyze" do
    test "analyzes specific pool" do
      params = %{action: :analyze, pool: "0xbebc44782c7db0a1a60cb6fe97d0b483032ff1c7"}
      assert {:ok, result} = CurveFinanceEngine.run(params)
      assert result.tvl > 0
      assert result.recommendations != nil
    end

    test "lists top pools" do
      params = %{action: :analyze}
      assert {:ok, result} = CurveFinanceEngine.run(params)
      assert result.pools != nil
    end
  end

  describe "run/1 - action: optimize" do
    test "finds optimal yield strategy" do
      params = %{action: :optimize, amount: 50_000, tokens: ["USDC"], risk_tolerance: :moderate}
      assert {:ok, result} = CurveFinanceEngine.run(params)
      assert result.expected_apy > 0
      assert result.expected_return_usd > 0
    end
  end

  describe "run/1 - action: monitor" do
    test "monitors positions and gauges" do
      params = %{action: :monitor, wallet: "0x1234567890abcdef1234567890abcdef12345678"}
      assert {:ok, result} = CurveFinanceEngine.run(params)
      assert result.gauges != nil
    end
  end

  describe "run/1 - action: swap" do
    test "optimizes swap route" do
      params = %{action: :swap, from: "USDC", to: "DAI", amount: 100_000}
      assert {:ok, result} = CurveFinanceEngine.run(params)
      assert result.slippage >= 0
    end
  end

  describe "full_cycle/1" do
    test "executes full analysis and optimization cycle" do
      params = %{wallet: "0x1234567890abcdef1234567890abcdef12345678", amount: 50_000, tokens: ["USDC"]}
      assert {:ok, result} = CurveFinanceEngine.full_cycle(params)
      assert result.summary != nil
      assert result.last_updated != nil
    end
  end
end
