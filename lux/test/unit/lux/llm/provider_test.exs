defmodule Lux.LLM.ProviderTest do
  use UnitCase, async: true

  alias Lux.LLM.Provider
  alias Lux.LLM.Provider.{Info, ModelInfo, Response}

  describe "Provider.provider?/1" do
    test "returns true for modules with call/3" do
      assert Provider.provider?(Lux.LLM.OpenAI)
      assert Provider.provider?(Lux.LLM.Anthropic)
      assert Provider.provider?(Lux.LLM.TogetherAI)
      assert Provider.provider?(Lux.LLM.Mira)
    end

    test "returns false for non-provider modules" do
      refute Provider.provider?(String)
      refute Provider.provider?(Enum)
    end

    test "returns false for non-atoms" do
      refute Provider.provider?("not_a_module")
      refute Provider.provider?(123)
    end
  end

  describe "Response" do
    test "creates response with defaults" do
      response = %Response{}
      assert response.content == nil
      assert response.tool_calls == []
      assert response.finish_reason == nil
      assert response.model == nil
      assert response.provider == nil
      assert response.usage == nil
      assert response.metadata == %{}
      assert response.latency_ms == nil
    end

    test "creates response with values" do
      response = %Response{
        content: "Hello!",
        model: "gpt-4o",
        provider: Lux.LLM.OpenAI,
        finish_reason: "stop",
        usage: %{input_tokens: 10, output_tokens: 5},
        latency_ms: 450
      }

      assert response.content == "Hello!"
      assert response.model == "gpt-4o"
    end

    test "estimated_cost with nil usage returns 0.0" do
      response = %Response{usage: nil}
      assert 0.0 == Response.estimated_cost(response, 0.001, 0.002)
    end

    test "estimated_cost calculates correctly" do
      response = %Response{
        usage: %{input_tokens: 1000, output_tokens: 500}
      }

      cost = Response.estimated_cost(response, 0.00001, 0.00002)
      # 1000 * 0.00001 + 500 * 0.00002 = 0.01 + 0.01 = 0.02
      assert_in_delta cost, 0.02, 0.0001
    end
  end

  describe "Info" do
    test "creates info with defaults" do
      info = %Info{}
      assert info.name == nil
      assert info.models == []
    end

    test "find_model finds a model by name" do
      info = %Info{
        models: [
          %ModelInfo{name: "model-a", capabilities: [:chat]},
          %ModelInfo{name: "model-b", capabilities: [:chat, :tool_use]}
        ]
      }

      found = Info.find_model(info, "model-b")
      assert found.name == "model-b"
      assert :tool_use in found.capabilities
    end

    test "find_model returns nil for unknown model" do
      info = %Info{models: [%ModelInfo{name: "model-a"}]}
      assert nil == Info.find_model(info, "nonexistent")
    end
  end

  describe "ModelInfo" do
    test "creates model info with defaults" do
      model = %ModelInfo{}
      assert model.name == ""
      assert model.capabilities == [:chat]
      assert model.context_window == 4096
      assert model.cost_per_input_token == 0.0
      assert model.cost_per_output_token == 0.0
    end
  end

  describe "provider_info implementations" do
    test "OpenAI returns valid provider info" do
      info = Lux.LLM.OpenAI.provider_info()
      assert info.name == :openai
      assert info.display_name == "OpenAI"
      assert length(info.models) > 0

      gpt4o = Enum.find(info.models, &(&1.name == "gpt-4o"))
      assert gpt4o != nil
      assert :chat in gpt4o.capabilities
      assert :tool_use in gpt4o.capabilities
      assert gpt4o.context_window == 128_000
    end

    test "Anthropic returns valid provider info" do
      info = Lux.LLM.Anthropic.provider_info()
      assert info.name == :anthropic
      assert length(info.models) > 0
    end

    test "TogetherAI returns valid provider info" do
      info = Lux.LLM.TogetherAI.provider_info()
      assert info.name == :together_ai
      assert length(info.models) > 0
    end

    test "Mira returns valid provider info" do
      info = Lux.LLM.Mira.provider_info()
      assert info.name == :mira
      assert length(info.models) > 0
    end
  end
end
