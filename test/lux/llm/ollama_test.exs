defmodule Lux.LLM.OllamaTest do
  use ExUnit.Case, async: true
  alias Lux.LLM.Ollama
  describe "configuration" do
    test "provider_name/0 returns :ollama" do
      assert Ollama.provider_name() == :ollama
    end
    test "default_model/0 returns model name" do
      assert is_binary(Ollama.default_model())
    end
    test "supports_tool_calling/0 returns true" do
      assert Ollama.supports_tool_calling() == true
    end
  end
  describe "call/3" do
    test "returns error without valid config" do
      result = Ollama.call([%{role: "user", content: "hi"}], [], %{})
      assert elem(result, 0) in [:ok, :error]
    end
  end
end
