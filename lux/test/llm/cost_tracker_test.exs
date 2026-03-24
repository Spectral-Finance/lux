defmodule Lux.LLM.CostTrackerTest do
  use ExUnit.Case, async: true

  alias Lux.LLM.CostTracker

  setup do
    # Reset cost tracker before each test
    CostTracker.reset()
    :ok
  end

  describe "record/4" do
    test "records cost correctly" do
      :ok = CostTracker.record(:openai, "gpt-4", 1000, 500)

      total = CostTracker.get_total_costs()
      assert total.requests == 1
      assert total.cost > 0
    end
  end

  describe "calculate_cost/4" do
    test "calculates GPT-4 cost correctly" do
      cost = CostTracker.calculate_cost(:openai, "gpt-4", 1000, 1000)

      # GPT-4: $0.03/1k input + $0.06/1k output
      assert_in_delta cost, 0.09, 0.001
    end

    test "calculates GPT-3.5-turbo cost correctly" do
      cost = CostTracker.calculate_cost(:openai, "gpt-3.5-turbo", 1000, 1000)

      # GPT-3.5: $0.0005/1k input + $0.0015/1k output
      assert_in_delta cost, 0.002, 0.001
    end
  end

  describe "get_costs_by_provider/1" do
    test "returns provider costs" do
      CostTracker.record(:openai, "gpt-4", 1000, 500)
      CostTracker.record(:openai, "gpt-4", 500, 250)

      costs = CostTracker.get_costs_by_provider(:openai)

      assert costs.requests == 2
      assert costs.cost > 0
    end
  end

  describe "set_budget/2 and budget_exceeded?/1" do
    test "tracks budget" do
      CostTracker.set_budget(:daily, 0.01)

      refute CostTracker.budget_exceeded?(:daily)

      # Record enough to exceed budget
      CostTracker.record(:openai, "gpt-4", 1000, 1000)

      assert CostTracker.budget_exceeded?(:daily)
    end
  end

  describe "get_history/1" do
    test "returns request history" do
      CostTracker.record(:openai, "gpt-4", 1000, 500)
      CostTracker.record(:anthropic, "claude-3-opus-20240229", 500, 250)

      history = CostTracker.get_history(10)

      assert length(history) == 2
    end
  end
end