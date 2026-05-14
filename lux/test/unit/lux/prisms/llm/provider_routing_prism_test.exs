defmodule Lux.Prisms.LLM.ProviderRoutingPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.LLM.ProviderRoutingPrism

  test "returns a provider routing plan" do
    assert {:ok, plan} =
             ProviderRoutingPrism.handler(
               %{
                 prompt: "Route this request",
                 capabilities: [:chat, :tools],
                 strategy: :cost,
                 estimated_input_tokens: 1_000,
                 estimated_output_tokens: 500
               },
               %{agent: %{name: "RouterAgent"}}
             )

    assert plan.selected != nil
    assert plan.fallback_chain != []
    assert plan.estimated_cost.total_usd >= 0.0
    assert :cost_tracking_and_optimization in plan.coverage
  end

  test "exposes prism schema" do
    view = ProviderRoutingPrism.view()

    assert view.name == "LLM Provider Routing"
    assert Map.has_key?(view.input_schema.properties, :capabilities)
    assert "fallback_chain" in view.output_schema.required
  end
end
