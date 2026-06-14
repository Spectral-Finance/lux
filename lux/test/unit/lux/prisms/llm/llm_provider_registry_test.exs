defmodule Lux.Prisms.LLM.LLMProviderRegistryPrismTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.LLM.LLMProviderRegistryPrism

  describe "list_providers" do
    test "returns all registered providers" do
      assert {:ok, %{status: "success", providers: providers}} =
        LLMProviderRegistryPrism.handler(%{action: "list_providers"}, %{})
      assert "openrouter" in providers
      assert "ollama" in providers
      assert "perplexity" in providers
      assert "together_ai" in providers
    end
  end

  describe "get_best_provider" do
    test "returns cheapest provider within cost limit" do
      assert {:ok, %{status: "success", provider: provider, model: model}} =
        LLMProviderRegistryPrism.handler(%{action: "get_best_provider", task: "chat", max_cost_per_1k: 0.1}, %{})
      assert is_binary(provider)
      assert is_binary(model)
    end

    test "returns ollama for zero cost limit" do
      assert {:ok, %{status: "success", provider: "ollama"}} =
        LLMProviderRegistryPrism.handler(%{action: "get_best_provider", task: "chat", max_cost_per_1k: 0.0}, %{})
    end
  end

  describe "get_provider_models" do
    test "returns models for valid provider" do
      assert {:ok, %{status: "success", provider: "openrouter", models: models}} =
        LLMProviderRegistryPrism.handler(%{action: "get_provider_models", provider: "openrouter"}, %{})
      assert is_map(models)
    end

    test "returns error for unknown provider" do
      assert {:error, _} =
        LLMProviderRegistryPrism.handler(%{action: "get_provider_models", provider: "unknown"}, %{})
    end
  end
end
