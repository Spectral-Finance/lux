defmodule Lux.LLM.ProviderTest do
  use UnitAPICase, async: true

  alias Lux.LLM.ModelConfig
  alias Lux.LLM.ProviderConfig

  describe "Lux.LLM.ModelConfig struct" do
    test "instantiates with default values" do
      model = %ModelConfig{
        id: "test-model",
        name: "Test Model",
        provider_id: :test_provider
      }

      assert model.id == "test-model"
      assert model.name == "Test Model"
      assert model.provider_id == :test_provider
      assert model.cost_per_1k_prompt_tokens == 0.0
      assert model.cost_per_1k_completion_tokens == 0.0
      assert model.capabilities == [:tools, :json_schema]
      assert model.context_window == 128_000
    end

    test "instantiates with custom attributes" do
      model = %ModelConfig{
        id: "gpt-4o",
        name: "GPT-4o",
        provider_id: :openai,
        cost_per_1k_prompt_tokens: 0.0025,
        cost_per_1k_completion_tokens: 0.01,
        capabilities: [:tools, :vision, :json_schema],
        context_window: 128_000
      }

      assert model.id == "gpt-4o"
      assert model.cost_per_1k_prompt_tokens == 0.0025
      assert :vision in model.capabilities
    end
  end

  describe "Lux.LLM.ProviderConfig struct" do
    test "instantiates with defaults" do
      config = %ProviderConfig{
        id: :openai,
        module: Lux.LLM.OpenAI
      }

      assert config.id == :openai
      assert config.module == Lux.LLM.OpenAI
      assert config.models == []
      assert config.status == :active
    end
  end
end
