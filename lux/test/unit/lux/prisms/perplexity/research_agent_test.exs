defmodule Lux.Prisms.Perplexity.ResearchAgentTest do
  use ExUnit.Case, async: false

  import Mock

  alias Lux.Prisms.Perplexity.ResearchAgent
  alias Lux.Lenses.Perplexity.Search

  describe "handler/2" do
    test "successfully researches a topic" do
      mock_response = {:ok, %{
        answer: "Elixir is awesome.",
        citations: ["https://elixir-lang.org"],
        usage: %{"total_tokens" => 10}
      }}

      with_mock Search, [focus: fn _params -> mock_response end] do
        assert {:ok, result} = ResearchAgent.run(%{topic: "Elixir", depth: "basic"})
        
        assert result.summary == "Elixir is awesome."
        assert result.citations == ["https://elixir-lang.org"]
        assert result.model_used == "sonar"
      end
    end

    test "handles api errors gracefully" do
      with_mock Search, [focus: fn _params -> {:error, "API Rate limit"} end] do
        assert {:error, error} = ResearchAgent.run(%{topic: "Elixir"})
        
        assert String.contains?(error, "Research failed")
        assert String.contains?(error, "API Rate limit")
      end
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = ResearchAgent.view()

      assert prism.input_schema.required == ["topic"]
      assert Map.has_key?(prism.input_schema.properties, :topic)
      assert Map.has_key?(prism.input_schema.properties, :depth)
    end

    test "validates output schema" do
      prism = ResearchAgent.view()

      assert prism.output_schema.required == ["summary", "citations", "model_used"]
      assert Map.has_key?(prism.output_schema.properties, :summary)
      assert Map.has_key?(prism.output_schema.properties, :citations)
      assert Map.has_key?(prism.output_schema.properties, :model_used)
    end
  end
end
