defmodule Lux.Prisms.CurveFinance.GaugesVotingPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.CurveFinance.GaugesVotingPrism

  describe "run/1" do
    test "optimizes gauge voting strategy" do
      params = %{veCRV_amount: 50_000, vote_count: 10}
      assert {:ok, result} = GaugesVotingPrism.run(params)
      assert result.expected_apy > 0
      assert result.total_incentive_usd > 0
      assert length(result.votes) > 0
    end

    test "applies optimization when requested" do
      params = %{veCRV_amount: 50_000, vote_count: 5, optimize: true}
      assert {:ok, result} = GaugesVotingPrism.run(params)
      assert result.optimization_applied == true
    end
  end

  describe "simulate_strategies/1" do
    test "returns multiple strategy options" do
      params = %{veCRV_amount: 50_000, vote_count: 10}
      assert {:ok, result} = GaugesVotingPrism.simulate_strategies(params)
      assert length(result.strategies) == 3
    end
  end
end
