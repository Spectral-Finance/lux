defmodule Lux.Prisms.CurveFinance.YieldOptimizerPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.CurveFinance.YieldOptimizerPrism

  describe "run/1" do
    test "optimizes yield for conservative risk tolerance" do
      params = %{amount: 10_000, tokens: ["USDC"], risk_tolerance: :conservative}
      assert {:ok, result} = YieldOptimizerPrism.run(params)
      assert result.expected_apy > 0
      assert result.risk_score >= 0.85
    end

    test "optimizes yield for aggressive risk tolerance" do
      params = %{amount: 50_000, tokens: ["USDC"], risk_tolerance: :aggressive}
      assert {:ok, result} = YieldOptimizerPrism.run(params)
      assert result.expected_apy > 0
    end

    test "calculates expected return based on time horizon" do
      params = %{amount: 10_000, tokens: ["USDC"], time_horizon: 365}
      assert {:ok, result} = YieldOptimizerPrism.run(params)
      assert result.expected_return_usd > 0
    end
  end

  describe "compare_strategies/1" do
    test "returns multiple strategies for comparison" do
      params = %{amount: 10_000, tokens: ["USDC"]}
      assert {:ok, result} = YieldOptimizerPrism.compare_strategies(params)
      assert result.count > 1
    end
  end
end
