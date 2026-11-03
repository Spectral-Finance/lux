defmodule Lux.Prisms.LlmPrismsTest do
  use UnitCase, async: true

  alias Lux.Prisms.Llm.ModelSelectorPrism
  alias Lux.Prisms.Llm.FallbackChainPrism
  alias Lux.Prisms.Llm.CostTrackerPrism
  alias Lux.Prisms.Llm.ProviderHealthPrism
  alias Lux.Prisms.Llm.PromptOptimizerPrism

  describe "ModelSelectorPrism" do
    test "selects model" do
      input = %{strategy: "cost_optimized"}
      assert {:ok, result} = ModelSelectorPrism.run(input)
      assert is_binary(result.model)
      assert result.tier == "cost_optimized"
    end
  end

  describe "FallbackChainPrism" do
    test "creates provider chain" do
      input = %{primary_provider: "openai"}
      assert {:ok, result} = FallbackChainPrism.run(input)
      assert result.primary == "openai"
      assert result.total_providers >= 3
    end
  end

  describe "CostTrackerPrism" do
    test "estimates cost" do
      input = %{model: "gpt-4o-mini", prompt_tokens: 5000, completion_tokens: 500}
      assert {:ok, result} = CostTrackerPrism.run(input)
      assert result.total_tokens == 5500
      assert result.total_cost_usd > 0.0
    end
  end

  describe "ProviderHealthPrism" do
    test "returns provider status" do
      input = %{provider: "openai"}
      assert {:ok, result} = ProviderHealthPrism.run(input)
      assert result.status == "online"
      assert result.avg_latency_ms > 0
    end
  end

  describe "PromptOptimizerPrism" do
    test "optimizes prompt" do
      input = %{user_prompt: "  Hello   world!  "}
      assert {:ok, result} = PromptOptimizerPrism.run(input)
      assert result.optimized_user_prompt == "Hello world!"
      assert is_binary(result.cache_key)
    end
  end
end
