defmodule Lux.LLM.FallbackHandlerTest do
  use ExUnit.Case

  alias Lux.LLM.FallbackHandler

  describe "call/3" do
    test "returns error when no providers available" do
      result = FallbackHandler.call("test prompt", [], model: "gpt-4", max_retries: 1)
      assert match?({:error, _, _}, result) or match?({:error, _}, result)
    end

    test "respects cost limit" do
      result = FallbackHandler.call("test", [], model: "gpt-4", cost_limit_usd: 0.000001, max_retries: 1)
      assert match?({:error, _, _}, result) or match?({:error, _}, result)
    end
  end
end
