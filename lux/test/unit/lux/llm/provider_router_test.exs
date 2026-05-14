defmodule Lux.LLM.ProviderRouterTest do
  use UnitCase, async: true

  alias Lux.LLM.ProviderRouter

  test "selects cheapest provider when cost strategy is requested" do
    plan =
      ProviderRouter.route(%{
        capabilities: [:chat],
        strategy: :cost,
        estimated_input_tokens: 10_000,
        estimated_output_tokens: 5_000
      })

    assert plan.selected.provider_id == :mira
    assert plan.selected.model.id == "llama-3.1-8b-instruct"
    assert plan.estimated_cost.total_usd == 0.0015
    assert :automatic_model_selection in plan.coverage
  end

  test "selects tool-capable model and creates fallback chain" do
    plan =
      ProviderRouter.route(%{
        capabilities: [:chat, :tools, :json],
        strategy: :balanced,
        estimated_input_tokens: 1_000,
        estimated_output_tokens: 500
      })

    assert plan.selected.provider_id == :openai
    assert plan.selected.model.id == "gpt-4o-mini"
    assert Enum.any?(plan.fallback_chain, &(&1.provider_id == :anthropic))
    assert :smart_fallback_handling in plan.coverage
  end

  test "honors preferred and denied providers" do
    preferred =
      ProviderRouter.route(%{
        capabilities: [:chat],
        preferred_provider: :anthropic,
        strategy: :quality
      })

    denied =
      ProviderRouter.route(%{
        capabilities: [:chat],
        denied_providers: [:mira, :openai, :anthropic],
        strategy: :cost
      })

    assert preferred.selected.provider_id == :anthropic
    assert denied.selected.provider_id == :together_ai
  end

  test "applies budget and latency limits" do
    no_candidate =
      ProviderRouter.route(%{
        capabilities: [:chat, :tools, :json, :reasoning],
        max_cost_usd: 0.000_001,
        estimated_input_tokens: 20_000,
        estimated_output_tokens: 10_000
      })

    fast =
      ProviderRouter.route(%{
        capabilities: [:chat],
        max_latency_ms: 900,
        strategy: :latency
      })

    assert no_candidate.selected == nil
    assert no_candidate.optimization.rejected_by_budget?
    assert fast.selected.provider_id == :mira
  end

  test "builds stable cache plan and key" do
    plan =
      ProviderRouter.route(%{
        prompt: "Summarize this",
        capabilities: [:chat],
        cache_ttl_seconds: 60,
        temperature: 0.2
      })

    key =
      ProviderRouter.cache_key(%{
        prompt: "Summarize this",
        provider: plan.selected.provider_id,
        model: plan.selected.model.id,
        temperature: 0.2
      })

    assert plan.cache.enabled?
    assert plan.cache.ttl_seconds == 60
    assert plan.cache.key == key
    assert byte_size(plan.cache.key) == 64
  end

  test "summarizes usage cost and performance by provider" do
    summary =
      ProviderRouter.usage_summary([
        %{provider: :openai, latency_ms: 1000, cost_usd: 0.01, status: :ok},
        %{provider: :openai, latency_ms: 2000, cost_usd: 0.02, status: :error},
        %{provider: :anthropic, latency_ms: 1500, cost_usd: 0.03, status: :ok}
      ])

    assert summary.total_requests == 3
    assert summary.total_cost_usd == 0.06
    assert summary.providers.openai.requests == 2
    assert summary.providers.openai.failures == 1
    assert summary.providers.openai.average_latency_ms == 1500.0
  end

  test "accepts custom string keyed provider metadata" do
    plan =
      ProviderRouter.route(%{
        "capabilities" => ["chat", "tools"],
        "providers" => [
          %{
            "id" => "local",
            "priority" => "1",
            "models" => [
              %{
                "id" => "local-tools",
                "capabilities" => ["chat", "tools"],
                "input_cost_per_million" => "0",
                "output_cost_per_million" => "0",
                "latency_ms" => "100",
                "quality" => "0.7"
              }
            ]
          }
        ]
      })

    assert plan.selected.provider_id == :local
    assert plan.selected.model.id == "local-tools"
    assert plan.selected.estimated_cost_usd == 0.0
  end
end
