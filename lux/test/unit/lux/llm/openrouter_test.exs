defmodule Lux.LLM.OpenRouterTest do
  use ExUnit.Case, async: true
  alias Lux.LLM.OpenRouter

  test "builds OpenRouter payload with fallback routing and estimates token cost" do
    {:ok, payload} =
      OpenRouter.build_chat_payload(%{
        model: "deepseek/deepseek-r1",
        fallback_models: ["meta-llama/llama-3.3-70b-instruct"],
        messages: [%{role: "user", content: "Analyze ETH yield"}]
      })

    assert payload.route == "fallback"
    assert length(payload.models) == 2

    cost = OpenRouter.estimate_cost("meta-llama/llama-3.3-70b-instruct", 10_000, 2_000)
    assert cost == 0.0018
  end
end
