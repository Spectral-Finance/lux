defmodule Lux.LLM.ProviderRegistryTest do
  use UnitCase, async: true

  alias Lux.LLM.ProviderRegistry
  alias Lux.LLM.ProviderRegistry.Model

  test "registers provider metadata and models" do
    registry =
      %{}
      |> ProviderRegistry.register(:test_provider, Lux.LLM.OpenAI,
        default_model: "fast-model",
        priority: 5,
        models: [
          ProviderRegistry.model("fast-model",
            capabilities: [:chat, :json],
            input_cost_per_million: 0.10,
            output_cost_per_million: 0.20
          )
        ]
      )

    provider = registry.test_provider

    assert provider.name == :test_provider
    assert provider.module == Lux.LLM.OpenAI
    assert provider.default_model == "fast-model"
    assert %Model{id: "fast-model"} = provider.models["fast-model"]
  end

  test "selects a provider by required capabilities" do
    assert {:ok, candidate} =
             ProviderRegistry.select(capabilities: [:tools, :json], sort: :cost)

    assert candidate.provider.name in [:openai, :anthropic]
    assert :tools in candidate.model.capabilities
    assert :json in candidate.model.capabilities
  end

  test "filters by provider and model" do
    assert {:ok, candidate} =
             ProviderRegistry.select(provider: :anthropic, model: "claude-3-5-sonnet-latest")

    assert candidate.provider.name == :anthropic
    assert candidate.module == Lux.LLM.Anthropic
    assert candidate.model.id == "claude-3-5-sonnet-latest"
  end

  test "builds an ordered fallback plan" do
    plan = ProviderRegistry.fallback_plan(capabilities: [:chat, :json], sort: :latency)

    assert length(plan) >= 3
    assert Enum.all?(plan, &(:chat in &1.model.capabilities))
    assert Enum.all?(plan, &(:json in &1.model.capabilities))
    assert hd(plan).model.latency_ms <= List.last(plan).model.latency_ms
  end

  test "applies cost ceilings to selection" do
    assert {:ok, candidate} =
             ProviderRegistry.select(
               capabilities: [:chat, :json],
               usage: %{input_tokens: 1_000, output_tokens: 1_000},
               max_estimated_cost_usd: 0.001,
               sort: :cost
             )

    assert ProviderRegistry.estimate_cost(candidate.model, %{
             input_tokens: 1_000,
             output_tokens: 1_000
           }) <= 0.001
  end

  test "returns no-provider errors for impossible requirements" do
    assert {:error, :no_provider_available} =
             ProviderRegistry.select(capabilities: [:audio, :fine_tuning])
  end

  test "summarizes usage and estimated cost" do
    {:ok, candidate} = ProviderRegistry.select(provider: :openai, model: "gpt-4o-mini")

    summary =
      ProviderRegistry.usage_summary(candidate, %{
        input_tokens: 100_000,
        output_tokens: 10_000,
        latency_ms: 875
      })

    assert summary.provider == :openai
    assert summary.model == "gpt-4o-mini"
    assert summary.estimated_cost_usd == 0.021
    assert summary.latency_ms == 875
  end
end
