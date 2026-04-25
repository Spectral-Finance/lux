defmodule Lux.LLM.OllamaTest do
  use ExUnit.Case, async: true

  alias Lux.LLM.Ollama

  describe "models/0" do
    test "returns default model when Ollama not running" do
      models = Ollama.models()
      assert is_list(models)
      assert "llama3" in models or length(models) > 0
    end
  end

  describe "estimate_cost/3" do
    test "always returns zero for local models" do
      assert Ollama.estimate_cost("llama3", 10000, 5000) == 0.0
      assert Ollama.estimate_cost("mistral", 1000, 500) == 0.0
    end
  end

  describe "available?/0" do
    test "returns boolean" do
      result = Ollama.available?()
      assert is_boolean(result)
    end
  end
end
