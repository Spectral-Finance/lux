defmodule Lux.Prisms.LLM.LLMCostTrackerPrismTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.LLM.LLMCostTrackerPrism

  describe "estimate_cost" do
    test "estimates cost for openrouter gpt-4o-mini" do
      assert {:ok, %{status: "success", estimated_cost_usd: cost}} =
        LLMCostTrackerPrism.handler(%{
          action: "estimate_cost",
          provider: "openrouter",
          model: "openai/gpt-4o-mini",
          input_tokens: 1000,
          output_tokens: 500
        }, %{})
      assert is_float(cost)
      assert cost > 0
    end

    test "ollama has zero cost" do
      assert {:ok, %{status: "success", estimated_cost_usd: 0.0}} =
        LLMCostTrackerPrism.handler(%{
          action: "estimate_cost",
          provider: "ollama",
          model: "llama3",
          input_tokens: 1000,
          output_tokens: 500
        }, %{})
    end
  end

  describe "compare_providers" do
    test "returns sorted comparison for chat task" do
      assert {:ok, %{status: "success", comparison: comparison}} =
        LLMCostTrackerPrism.handler(%{
          action: "compare_providers",
          task: "chat",
          input_tokens: 1000,
          output_tokens: 500
        }, %{})
      assert length(comparison) > 0
      costs = Enum.map(comparison, & &1.cost_usd)
      assert costs == Enum.sort(costs)
    end
  end

  describe "get_cheapest" do
    test "returns cheapest provider" do
      assert {:ok, %{status: "success", cheapest_provider: provider}} =
        LLMCostTrackerPrism.handler(%{
          action: "get_cheapest",
          task: "chat",
          input_tokens: 1000,
          output_tokens: 500
        }, %{})
      assert provider == "ollama"
    end
  end
end
