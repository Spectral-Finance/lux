defmodule Lux.LLM.ModelSelectorTest do
  use ExUnit.Case, async: true

  alias Lux.LLM.ModelSelector

  describe "select_best/1" do
    test "selects provider based on cost priority" do
      {provider, _model} = ModelSelector.select_best(%{priority: :cost})

      # Together AI should be cheapest
      assert provider == :together_ai
    end

    test "selects provider based on quality priority" do
      {_provider, model} = ModelSelector.select_best(%{priority: :quality})

      # Should select a high quality model
      assert model in ["claude-3-opus-20240229", "gpt-4", "gpt-4-turbo"]
    end

    test "filters by features" do
      {provider, model} = ModelSelector.select_best(%{
        priority: :quality,
        features: [:vision]
      })

      # Only OpenAI and Anthropic have vision
      assert provider in [:openai, :anthropic]
    end

    test "excludes specified providers" do
      {provider, _model} = ModelSelector.select_best(%{
        priority: :cost,
        exclude: [:together_ai]
      })

      # Should not select together_ai
      refute provider == :together_ai
    end
  end

  describe "get_cost/4" do
    test "calculates cost correctly" do
      cost = ModelSelector.get_cost(:openai, "gpt-4", 1000, 1000)

      # GPT-4: $0.03/1k input + $0.06/1k output
      # 1000 input + 1000 output = $0.03 + $0.06 = $0.09
      assert_in_delta cost, 0.09, 0.001
    end

    test "returns 0 for unknown provider" do
      assert 0.0 == ModelSelector.get_cost(:unknown, "model", 1000, 1000)
    end
  end

  describe "build_chain/1" do
    test "builds fallback chain" do
      chain = ModelSelector.build_chain(%{priority: :cost})

      assert is_list(chain)
      assert length(chain) <= 5

      # First should be cheapest
      {first_provider, _} = List.first(chain)
      assert first_provider == :together_ai
    end
  end
end