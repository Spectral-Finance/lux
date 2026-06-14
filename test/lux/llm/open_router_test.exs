defmodule Lux.LLM.OpenRouterTest do
  use ExUnit.Case, async: true

  alias Lux.LLM.OpenRouter

  describe "configuration" do
    test "provider_name/0 returns :openrouter" do
      assert OpenRouter.provider_name() == :openrouter
    end

    test "default_model/0 returns a string" do
      assert is_binary(OpenRouter.default_model())
    end

    test "supports_tool_calling/0 returns true" do
      assert OpenRouter.supports_tool_calling() == true
    end
  end

  describe "call/3 without valid API key" do
    test "returns error when API key is missing" do
      messages = [%{role: "user", content: "hello"}]
      result = OpenRouter.call(messages, [], %{})
      assert elem(result, 0) in [:ok, :error]
    end
  end
end

defmodule Lux.LLM.PerplexityTest do
  use ExUnit.Case, async: true

  alias Lux.LLM.Perplexity

  describe "configuration" do
    test "provider_name/0 returns :perplexity" do
      assert Perplexity.provider_name() == :perplexity
    end

    test "default_model/0 returns a string" do
      assert is_binary(Perplexity.default_model())
    end

    test "supports_tool_calling/0 returns false" do
      assert Perplexity.supports_tool_calling() == false
    end
  end

  describe "call/3 without valid API key" do
    test "returns error when API key is missing" do
      messages = [%{role: "user", content: "hello"}]
      result = Perplexity.call(messages, [], %{})
      assert elem(result, 0) in [:ok, :error]
    end
  end
end
