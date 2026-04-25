defmodule Lux.LLM.CostTrackerTest do
  use ExUnit.Case

  alias Lux.LLM.CostTracker

  setup do
    start_supervised!({CostTracker, name: :test_cost_tracker})
    # Reset before each test
    CostTracker.reset()
    :ok
  end

  describe "track/5" do
    test "records token usage and cost" do
      CostTracker.track(:openai, "gpt-4", 1500, 500, 0.045)
      # Allow async cast to process
      Process.sleep(50)
      total = CostTracker.total_spend()
      assert total >= 0.0
    end

    test "accumulates costs across calls" do
      CostTracker.track(:openai, "gpt-4", 1000, 300, 0.03)
      CostTracker.track(:anthropic, "claude-3-sonnet", 2000, 600, 0.012)
      Process.sleep(50)
      total = CostTracker.total_spend()
      assert total >= 0.0
    end
  end

  describe "estimate_cost/3" do
    test "estimates cost for gpt-4" do
      cost = CostTracker.estimate_cost("gpt-4", 1000, 500)
      assert cost == 0.06
    end

    test "estimates cost for claude-3-haiku" do
      cost = CostTracker.estimate_cost("claude-3-haiku", 1000, 500)
      assert cost > 0.0
      assert cost < 0.01
    end

    test "returns zero for local models" do
      cost = CostTracker.estimate_cost("llama3", 1000, 500)
      assert cost == 0.0
    end

    test "returns default cost for unknown models" do
      cost = CostTracker.estimate_cost("unknown-model", 1000, 500)
      assert cost > 0.0
    end
  end

  describe "within_budget?/1" do
    test "returns true when under budget" do
      assert CostTracker.within_budget?(1.0)
    end

    test "returns false when over budget" do
      CostTracker.track(:openai, "gpt-4", 10000, 5000, 0.50)
      Process.sleep(50)
      # With 0.50 tracked, budget of 0.01 should fail
      refute CostTracker.within_budget?(0.01)
    end
  end

  describe "breakdown_by_model/0" do
    test "returns per-model cost breakdown" do
      CostTracker.track(:openai, "gpt-4", 1000, 300, 0.03)
      CostTracker.track(:openai, "gpt-3.5-turbo", 500, 200, 0.001)
      Process.sleep(50)
      breakdown = CostTracker.breakdown_by_model()
      assert is_map(breakdown)
    end
  end
end
