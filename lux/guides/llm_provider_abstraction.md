# LLM Provider Abstraction Layer

The LLM Provider Abstraction Layer provides a universal interface for integrating
multiple LLM providers into the Lux framework. It enables automatic provider selection,
intelligent fallback handling, cost tracking, and performance monitoring.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Lux.LLM                          │
│  (Main entry point — call/3, call_with_fallback/3)  │
└──────────┬───────────────┬──────────────────────────┘
           │               │
    ┌──────▼──────┐  ┌─────▼──────────┐
    │  Registry   │  │ FallbackChain  │
    │ (providers, │  │ (retry logic,  │
    │  health)    │  │  circuit break)│
    └──────┬──────┘  └────────────────┘
           │
    ┌──────▼──────────────────────────┐
    │        Provider Behaviour       │
    │   ┌─────────┐ ┌──────────┐     │
    │   │ OpenAI  │ │Anthropic │ ... │
    │   └─────────┘ └──────────┘     │
    └─────────────────────────────────┘
           │
    ┌──────▼──────┐  ┌──────────────────┐
    │CostTracker  │  │PerformanceMonitor│
    └─────────────┘  └──────────────────┘
```

## Quick Start

### Basic Usage (Backward Compatible)

```elixir
# Uses default provider (OpenAI)
{:ok, response} = Lux.LLM.call("What is 2+2?", [], %{model: "gpt-4o"})

# Specify provider explicitly
{:ok, response} = Lux.LLM.call("Hello!", [], %{
  provider: :anthropic,
  model: "claude-3-5-sonnet-20241022",
  api_key: "sk-ant-..."
})
```

### Call with Fallback

```elixir
# Auto-fallback: tries healthy providers in order
{:ok, response, provider_used} = Lux.LLM.call_with_fallback("Hello!", [], %{})

# Explicit fallback chain
{:ok, response, provider_used} = Lux.LLM.call_with_fallback("Hello!", [], %{
  fallback_chain: [
    {:openai, %{model: "gpt-4o"}},
    {:anthropic, %{model: "claude-3-5-sonnet-20241022"}},
    {:together_ai, %{model: "mistralai/Mistral-7B-Instruct-v0.2"}}
  ]
})
```

### Automatic Model Selection

```elixir
# Select by capabilities
{:ok, provider, module, model} = Lux.LLM.ModelSelector.select(
  capabilities: [:chat, :tool_use],
  strategy: :cheapest
)

# Select with constraints
{:ok, provider, module, model} = Lux.LLM.ModelSelector.select(
  capabilities: [:chat, :vision],
  min_context_window: 100_000,
  max_cost_per_1k_tokens: 0.01,
  excluded_providers: [:mira]
)
```

## Provider Registry

The registry manages provider registration, lookup, and health tracking.

### Built-in Providers

| Provider | Name | Module |
|----------|------|--------|
| OpenAI | `:openai` | `Lux.LLM.OpenAI` |
| Anthropic | `:anthropic` | `Lux.LLM.Anthropic` |
| Together AI | `:together_ai` | `Lux.LLM.TogetherAI` |
| Mira Network | `:mira` | `Lux.LLM.Mira` |

### Registering Custom Providers

```elixir
# Register a custom provider
Lux.LLM.Registry.register(:my_provider, MyApp.LLM.CustomProvider, priority: 80)

# List all providers
Lux.LLM.Registry.list()
# => [{:openai, Lux.LLM.OpenAI, 90}, {:anthropic, Lux.LLM.Anthropic, 85}, ...]

# Get provider info
{:ok, info} = Lux.LLM.Registry.provider_info(:openai)
# => %Lux.LLM.Provider.Info{name: :openai, models: [...]}
```

### Health Tracking

The registry automatically tracks provider health:

```elixir
# Check provider health
health = Lux.LLM.Registry.health(:openai)
# => %{total_requests: 150, error_count: 2, avg_latency_ms: 450.0, ...}

# Get health score (0.0 to 1.0)
score = Lux.LLM.Registry.health_score(:openai)
# => 0.92

# Get providers sorted by health
Lux.LLM.Registry.healthy_providers()
# => [{:openai, Lux.LLM.OpenAI, 0.92}, {:anthropic, Lux.LLM.Anthropic, 0.88}, ...]
```

## Implementing a Custom Provider

To add a new LLM provider, implement the `Lux.LLM.Provider` behaviour:

```elixir
defmodule MyApp.LLM.CustomProvider do
  @behaviour Lux.LLM
  @behaviour Lux.LLM.Provider

  alias Lux.LLM.Provider.{Info, ModelInfo}

  @impl Lux.LLM.Provider
  def configured?(config) do
    not is_nil(Map.get(config, :api_key))
  end

  @impl Lux.LLM.Provider
  def provider_info do
    %Info{
      name: :custom,
      display_name: "My Custom Provider",
      module: __MODULE__,
      default_model: "custom-model-v1",
      models: [
        %ModelInfo{
          name: "custom-model-v1",
          capabilities: [:chat, :tool_use],
          context_window: 32_768,
          cost_per_input_token: 0.0001,
          cost_per_output_token: 0.0002
        }
      ]
    }
  end

  @impl Lux.LLM
  def call(prompt, tools, config) do
    # Your implementation here
    {:ok, %Lux.LLM.Response{content: "...", finish_reason: "stop"}}
  end
end
```

Then register it:

```elixir
Lux.LLM.Registry.register(:custom, MyApp.LLM.CustomProvider, priority: 70)
```

## Cost Tracking

The cost tracker records token usage and estimated costs:

```elixir
# Get cost summary
summary = Lux.LLM.cost_summary()
# => %{
#   total_cost: 0.0234,
#   total_input_tokens: 15000,
#   total_output_tokens: 8000,
#   total_requests: 42,
#   by_provider: %{openai: %{cost: 0.02, requests: 30}, ...},
#   by_model: %{"gpt-4o" => %{cost: 0.015, requests: 20}, ...}
# }

# Filter by time window
recent = Lux.LLM.cost_summary(since: System.system_time(:millisecond) - 3_600_000)

# Provider-specific costs
openai_costs = Lux.LLM.CostTracker.by_provider(:openai)
```

## Performance Monitoring

The performance monitor tracks latency, throughput, and error rates:

```elixir
# Get analytics
analytics = Lux.LLM.performance_analytics()
# => %{
#   total_requests: 150,
#   total_errors: 3,
#   error_rate: 0.02,
#   latency: %{p50: 450, p95: 1200, p99: 2500, avg: 520},
#   throughput: %{requests_per_minute: 12.5, tokens_per_second: 45.2},
#   by_provider: %{openai: %{...}, anthropic: %{...}}
# }

# Provider-specific metrics
metrics = Lux.LLM.PerformanceMonitor.provider_metrics(:openai)
```

## Model Selection Strategies

| Strategy | Description |
|----------|-------------|
| `:best_available` | Highest quality model (default) |
| `:cheapest` | Minimize cost |
| `:fastest` | Minimize latency using health data |
| `:balanced` | Balance cost, quality, and performance |

## Fallback Chain

The fallback chain provides resilient LLM calls:

```elixir
chain = Lux.LLM.FallbackChain.new(
  [
    {:openai, %{model: "gpt-4o"}},
    {:anthropic, %{model: "claude-3-5-sonnet-20241022"}},
    {:together_ai, %{model: "mistralai/Mistral-7B-Instruct-v0.2"}}
  ],
  max_retries: 2,
  base_backoff_ms: 200,
  circuit_breaker_threshold: 5
)

{:ok, response, provider_used} = Lux.LLM.FallbackChain.call(chain, prompt, tools, config)
```

### Circuit Breaker

When a provider has too many consecutive errors, it's temporarily skipped:

- Default threshold: 5 consecutive errors
- The circuit automatically closes when the provider recovers

## Configuration

### API Keys

```elixir
config :lux, :api_keys,
  openai: System.get_env("OPENAI_API_KEY"),
  anthropic: System.get_env("ANTHROPIC_API_KEY"),
  together: System.get_env("TOGETHER_API_KEY"),
  mira: System.get_env("MIRA_API_KEY")
```

### Default Provider

```elixir
config :lux, Lux.LLM, default_module: Lux.LLM.OpenAI
```

### With Agents

Agents seamlessly use the provider abstraction:

```elixir
defmodule MyAgent do
  use Lux.Agent,
    name: "My Agent",
    llm_config: %{
      provider: :anthropic,
      model: "claude-3-5-sonnet-20241022",
      temperature: 0.7
    }
end
```
