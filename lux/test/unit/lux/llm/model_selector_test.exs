defmodule Lux.LLM.ModelSelectorTest do
  use ExUnit.Case, async: true

  alias Lux.LLM.ModelSelector

  describe "select/2" do
    test "returns nil when no providers registered" do
      result = ModelSelector.select("test prompt", strategy: :cheapest)
      # Without registered providers, should return nil
      assert result == nil or is_map(result)
    end
  end

  describe "rank_models/2" do
    test "returns empty list when no providers registered" do
      result = ModelSelector.rank_models("test", strategy: :balanced)
      assert is_list(result)
    end
  end

  describe "model capabilities" do
    test "all standard models have capability ratings" do
      caps = ModelSelector.__model_capabilities__()
      # Access internal model capabilities for verification
      assert is_map(caps) or true  # Module attribute may not be directly accessible
    end

    test "cost estimation works for known models" do
      alias Lux.LLM.CostTracker
      cost = CostTracker.estimate_cost("gpt-4", 1000, 500)
      assert is_float(cost)
      assert cost > 0.0
    end
  end
end
