defmodule Lux.LLM.OptimizerTest do
  use UnitCase, async: true

  alias Lux.LLM.Optimizer

  describe "optimize_prompt/1" do
    test "removes duplicate whitespace and excessive newlines" do
      raw = "Hello      world!\n\n\n\n\nHow    are you?   "
      optimized = Optimizer.optimize_prompt(raw)

      assert optimized == "Hello world!\n\nHow are you?"
    end
  end

  describe "cache_key/2" do
    test "produces deterministic sha256 hash" do
      k1 = Optimizer.cache_key("System prompt", "User query")
      k2 = Optimizer.cache_key("System prompt", "User query")

      assert is_binary(k1)
      assert String.length(k1) == 64
      assert k1 == k2
    end
  end

  describe "estimate_tokens/1" do
    test "estimates token counts from length" do
      tokens = Optimizer.estimate_tokens("This is a simple sentence of 40 characters!")
      assert tokens >= 10
    end
  end
end
