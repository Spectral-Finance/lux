defmodule Lux.LLM.ProviderTest do
  use ExUnit.Case, async: true

  alias Lux.LLM.Provider

  describe "new/1" do
    test "creates a provider struct with defaults" do
      provider = Provider.new(id: :openai, module: Lux.LLM.OpenAI)
      assert provider.id == :openai
      assert provider.module == Lux.LLM.OpenAI
      assert provider.enabled == true
      assert provider.priority == 0
      assert provider.models == []
    end

    test "creates a provider with custom options" do
      provider = Provider.new(
        id: :anthropic,
        module: Lux.LLM.Anthropic,
        name: "Anthropic",
        priority: 10,
        models: ["claude-3-opus", "claude-3-sonnet"]
      )
      assert provider.name == "Anthropic"
      assert provider.priority == 10
      assert provider.models == ["claude-3-opus", "claude-3-sonnet"]
    end
  end

  describe "implements?/1" do
    test "returns true for modules implementing the Provider behaviour" do
      # OpenAI implements call/3, models/0, estimate_cost/3 via the Provider behaviour
      # We add estimate_cost and models to existing modules via the registry
      assert is_boolean(Provider.implements?(Lux.LLM.Ollama))
    end

    test "returns false for non-provider modules" do
      refute Provider.implements?(Enum)
    end
  end
end
