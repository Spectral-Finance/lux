# LLM Provider Abstraction Layer

Lux includes a universal LLM Provider Abstraction Layer that manages multiple LLM providers (`OpenAI`, `Anthropic`, `TogetherAI`, `Mira`, and custom providers) with automatic model selection, intelligent fallback chains, cost and latency monitoring, and response caching.

## Core Modules

- `Lux.LLM` — Unified public entrypoint (`call/3`, `route/3`, `select_model/3`, `register_provider/2`, `metrics/0`, `clear_cache/0`)
- `Lux.LLM.Provider` — Behaviour contract, `%ModelInfo{}` capability/cost metadata, `%Spec{}` registration descriptor, and response normalizer
- `Lux.LLM.ProviderRegistry` — Dynamic ETS registry with circuit-breaker health tracking
- `Lux.LLM.ModelSelector` — Task complexity estimation and strategy-driven model ranking (`:cost_optimized`, `:quality_optimized`, `:latency_optimized`, `:balanced`)
- `Lux.LLM.Router` — Execution engine handling caching, retries, provider failover, and telemetry recording
- `Lux.LLM.Telemetry` — Per-provider and per-model token, USD cost, and latency analytics
- `Lux.LLM.Cache` — Deterministic SHA-256 response cache with TTL expiration and capacity eviction

## Usage Examples

### 1. Automatic Model Selection

```elixir
# Automatically select the most cost-effective model for a simple prompt
{:ok, selection} = Lux.LLM.select_model("Summarize this paragraph", [], %{
  strategy: :cost_optimized
})

# Route a complex reasoning prompt with automatic model selection and normalized output
{:ok, response} = Lux.LLM.call(
  "Analyze step by step the trade-offs between optimistic and ZK rollups",
  [],
  %{
    strategy: :quality_optimized,
    normalize_response: true
  }
)
```

### 2. Intelligent Fallback Chains

```elixir
{:ok, response} = Lux.LLM.call(
  "Execute portfolio rebalance evaluation",
  [MyTradingPrism],
  %{
    provider: :openai,
    fallback_providers: [:anthropic, :together_ai],
    retry_attempts: 1,
    retry_backoff_ms: 200,
    cache: true,
    normalize_response: true
  }
)
```

### 3. Registering a Custom Provider

```elixir
Lux.LLM.register_provider(:custom_provider, %{
  module: MyApp.CustomLLMProvider,
  default_model: "custom-instruct-70b",
  priority: 95,
  models: [
    %{
      name: "custom-instruct-70b",
      tier: :balanced,
      context_window: 128_000,
      max_output_tokens: 4096,
      input_cost_per_1k: 0.0005,
      output_cost_per_1k: 0.0010,
      avg_latency_ms: 400,
      quality_score: 0.90,
      capabilities: [:tools, :json_mode]
    }
  ]
})
```

### 4. Inspecting Cost and Performance Telemetry

```elixir
metrics = Lux.LLM.metrics()
IO.inspect(metrics.global.total_cost_usd, label: "Total USD Cost")
IO.inspect(metrics.providers[:openai], label: "OpenAI Stats")
```
