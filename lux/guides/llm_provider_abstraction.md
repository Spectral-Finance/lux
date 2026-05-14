# LLM Provider Abstraction

`Lux.LLM.ProviderRegistry` is a credential-free routing layer for LLM providers.
It does not make network calls. Instead, it stores provider and model metadata so
callers can choose a model, build fallback plans, and estimate cost before
invoking an existing provider module.

## Select A Provider

```elixir
{:ok, candidate} =
  Lux.LLM.ProviderRegistry.select(
    capabilities: [:chat, :tools, :json],
    sort: :cost
  )

candidate.provider.name
candidate.model.id
candidate.module
```

Selection filters out disabled providers, checks model capabilities, applies
optional provider/model filters, and supports sorting by `:priority`, `:cost`, or
`:latency`.

## Build Fallbacks

```elixir
plan =
  Lux.LLM.ProviderRegistry.fallback_plan(
    capabilities: [:chat, :json],
    usage: %{input_tokens: 1_000, output_tokens: 500},
    max_estimated_cost_usd: 0.01
  )
```

Each plan entry contains the provider descriptor, model descriptor, and provider
module. The caller can try each entry in order and preserve existing provider
client behavior.

## Estimate Cost

```elixir
{:ok, candidate} =
  Lux.LLM.ProviderRegistry.select(provider: :openai, model: "gpt-4o-mini")

Lux.LLM.ProviderRegistry.usage_summary(candidate, %{
  input_tokens: 100_000,
  output_tokens: 10_000,
  latency_ms: 875
})
```

The summary includes provider, model, estimated cost, token counts, and latency.

## Custom Registries

```elixir
registry =
  %{}
  |> Lux.LLM.ProviderRegistry.register(:local, MyApp.LocalLLM,
    default_model: "local-small",
    priority: 1,
    models: [
      Lux.LLM.ProviderRegistry.model("local-small",
        capabilities: [:chat, :json],
        input_cost_per_million: 0,
        output_cost_per_million: 0
      )
    ]
  )
```

Custom registries make tests deterministic and allow applications to register
private or local providers without changing Lux's built-in provider modules.
