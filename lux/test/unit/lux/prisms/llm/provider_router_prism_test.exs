defmodule Lux.Prisms.LLM.ProviderRouterPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.LLM.ProviderRouterPrism

  test "routes a request and returns serializable provider metadata" do
    assert {:ok, result} =
             ProviderRouterPrism.run(%{
               capabilities: ["chat", "tools"],
               strategy: "cost",
               input_tokens: 1_000,
               output_tokens: 1_000
             })

    assert result.provider in ["open_ai", "anthropic", "together_ai", "mira"]
    assert is_binary(result.module)
    assert is_binary(result.model)
    assert is_number(result.estimated_cost)
    assert is_list(result.fallback_chain)
  end

  test "exposes the expected schemas" do
    prism = ProviderRouterPrism.view()

    assert prism.input_schema.properties.strategy.enum == ["balanced", "cost", "latency", "quality"]
    assert prism.output_schema.required == ["provider", "module", "model", "estimated_cost", "fallback_chain"]
  end
end
