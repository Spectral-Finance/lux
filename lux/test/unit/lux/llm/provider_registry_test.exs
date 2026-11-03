defmodule Lux.LLM.ProviderRegistryTest do
  use UnitCase, async: true

  alias Lux.LLM.ProviderRegistry

  describe "list_providers/0" do
    test "returns registered providers map" do
      providers = ProviderRegistry.list_providers()
      assert Map.has_key?(providers, :openai)
      assert Map.has_key?(providers, :anthropic)
      assert Map.has_key?(providers, :together_ai)
      assert Map.has_key?(providers, :groq)
    end
  end

  describe "get_provider/1" do
    test "retrieves provider details" do
      assert {:ok, openai} = ProviderRegistry.get_provider(:openai)
      assert openai.name == "OpenAI"
      assert openai.status == :online
      assert "gpt-4o" in openai.models
    end

    test "returns error on unknown provider" do
      assert {:error, :provider_not_found} = ProviderRegistry.get_provider(:unknown_llm)
    end
  end

  describe "providers_with_capability/1" do
    test "finds providers supporting tools" do
      providers = ProviderRegistry.providers_with_capability(:tools)
      assert :openai in providers
      assert :anthropic in providers
    end
  end
end
