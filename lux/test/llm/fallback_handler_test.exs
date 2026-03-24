defmodule Lux.LLM.FallbackHandlerTest do
  use ExUnit.Case, async: true

  alias Lux.LLM.FallbackHandler

  describe "get_fallbacks/2" do
    test "returns all other providers with :all strategy" do
      fallbacks = FallbackHandler.get_fallbacks(:openai, :all)

      assert is_list(fallbacks)
      refute {:openai, nil} in fallbacks
    end

    test "returns empty list with :none strategy" do
      fallbacks = FallbackHandler.get_fallbacks(:openai, :none)

      assert fallbacks == []
    end

    test "returns same tier providers with :same_tier strategy" do
      fallbacks = FallbackHandler.get_fallbacks(:openai, :same_tier)

      # OpenAI and Anthropic are same tier
      providers = Enum.map(fallbacks, fn {p, _} -> p end)

      assert :anthropic in providers
    end
  end
end