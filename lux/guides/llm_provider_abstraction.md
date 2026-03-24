# LLM Provider Abstraction Layer

This document describes the LLM Provider Abstraction Layer for Lux, providing unified access to multiple LLM providers with intelligent selection and fallback capabilities.

## Overview

The LLM Provider Abstraction Layer provides:

- **Universal Provider Interface** - Single API for all LLM providers
- **Automatic Model Selection** - Intelligent selection based on cost, speed, or quality
- **Smart Fallback Handling** - Automatic failover when providers fail
- **Cost Tracking** - Monitor and optimize API costs
- **Performance Monitoring** - Track latency and success rates

## Quick Start

```elixir
# Call with automatic provider selection
{:ok, response} = Lux.LLM.Provider.call("Hello, world!", [], %{})

# Call with specific provider
{:ok, response} = Lux.LLM.Provider.call("Hello!", [], %{
  provider: :openai,
  model: "gpt-4"
})

# Select best provider for a task
{provider, model} = Lux.LLM.Provider.select_best(%{priority: :cost})
```

## Configuration

Providers are automatically registered with default configurations. You can customize them:

```elixir
# Register a custom provider
Lux.LLM.Provider.register(:custom, %{
  module: MyApp.CustomLLM,
  models: ["custom-model-1", "custom-model-2"],
  cost_per_1k_tokens: %{
    "custom-model-1" => %{input: 0.01, output: 0.02}
  },
  max_tokens: 8192,
  features: [:streaming, :tools],
  priority: 5
})

# Update provider config
Lux.LLM.Provider.unregister(:deprecated_provider)
```

## Provider Selection

### Selection Strategies

| Strategy | Description |
|----------|-------------|
| `:cost` | Minimize cost per token |
| `:speed` | Minimize latency |
| `:quality` | Maximize output quality |
| `:balanced` | Balance between all factors |

### Selection Options

```elixir
# Select by cost
{provider, model} = Lux.LLM.Provider.select_best(%{
  priority: :cost
})

# Select with feature requirements
{provider, model} = Lux.LLM.Provider.select_best(%{
  priority: :quality,
  features: [:vision, :tools]
})

# Exclude certain providers
{provider, model} = Lux.LLM.Provider.select_best(%{
  priority: :balanced,
  exclude: [:slow_provider]
})

# Prefer certain providers
{provider, model} = Lux.LLM.Provider.select_best(%{
  priority: :speed,
  prefer: [:fast_provider]
})
```

## Fallback Handling

The system automatically handles provider failures:

```elixir
# Automatic fallback with all providers
{:ok, response} = Lux.LLM.Provider.call("Hello!", [], %{
  fallback: :all
})

# No fallback
{:ok, response} = Lux.LLM.Provider.call("Hello!", [], %{
  fallback: :none
})

# Same tier fallback only
{:ok, response} = Lux.LLM.Provider.call("Hello!", [], %{
  fallback: :same_tier
})
```

### Fallback Features

- **Exponential Backoff** - Retries with increasing delay
- **Circuit Breaker** - Prevents cascading failures
- **Intelligent Failover** - Falls back to alternative providers

## Cost Tracking

Track and monitor API costs:

```elixir
# Record a request (automatic when using Provider.call)
Lux.LLM.CostTracker.record(:openai, "gpt-4", 1000, 500)

# Get total costs
costs = Lux.LLM.CostTracker.get_total_costs()
# => %{cost: 1.50, requests: 100, tokens: 50000}

# Get costs by provider
provider_costs = Lux.LLM.CostTracker.get_costs_by_provider(:openai)

# Get costs by period
daily_costs = Lux.LLM.CostTracker.get_costs_by_period(:daily)

# Set budget limits
Lux.LLM.CostTracker.set_budget(:daily, 10.0)

# Check if budget exceeded
if Lux.LLM.CostTracker.budget_exceeded?(:daily) do
  # Stop making requests
end
```

## Performance Monitoring

Monitor provider performance:

```elixir
# Get stats for a provider
stats = Lux.LLM.Provider.get_stats(:openai)
# => %{
#   total_requests: 100,
#   successful_requests: 95,
#   avg_latency_ms: 250.5,
#   success_rate: 0.95
# }

# Get all provider stats
all_stats = Lux.LLM.Provider.get_all_stats()

# Get health status
health = Lux.LLM.PerformanceMonitor.get_health(:openai)
# => :healthy | :degraded | :unhealthy
```

## Provider Registry

Manage registered providers:

```elixir
# List all providers
providers = Lux.LLM.Provider.list_providers()
# => [:openai, :anthropic, :together_ai]

# Get provider config
config = Lux.LLM.Provider.get_config(:openai)

# Enable/disable providers
Lux.LLM.Provider.disable(:expensive_provider)
Lux.LLM.Provider.enable(:cheaper_provider)
```

## Default Providers

| Provider | Models | Cost Range | Features |
|----------|--------|------------|----------|
| OpenAI | gpt-4, gpt-4-turbo, gpt-3.5-turbo | $0.0005 - $0.06/1k | streaming, tools, vision, json_mode |
| Anthropic | claude-3-opus, claude-3-sonnet, claude-3-haiku | $0.00025 - $0.075/1k | streaming, tools, vision |
| Together AI | Mixtral-8x7B, Llama-3-70b | $0.0006 - $0.0009/1k | streaming, tools |

## Error Handling

```elixir
case Lux.LLM.Provider.call("Hello!", [], %{provider: :openai}) do
  {:ok, response} ->
    # Handle success

  {:error, {:all_providers_failed, errors}} ->
    # All providers failed

  {:error, {:invalid_api_key}} ->
    # Authentication error

  {:error, reason} ->
    # Other errors
end
```

## Testing

```bash
# Run unit tests
mix test test/llm/

# Run specific test
mix test test/llm/provider_test.exs
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Lux.LLM.Provider                   │
│            (Universal Provider Interface)            │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌─────────────────┐  ┌─────────────────┐         │
│  │  ModelSelector  │  │ FallbackHandler │         │
│  │  (Selection)    │  │  (Failover)     │         │
│  └─────────────────┘  └─────────────────┘         │
│                                                     │
│  ┌─────────────────┐  ┌─────────────────┐         │
│  │   CostTracker   │  │PerformanceMonitor│         │
│  │  (Costs)        │  │  (Monitoring)   │         │
│  └─────────────────┘  └─────────────────┘         │
│                                                     │
├─────────────────────────────────────────────────────┤
│               ProviderRegistry (ETS)                │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌─────────┐  ┌───────────┐  ┌────────────┐       │
│  │ OpenAI  │  │ Anthropic │  │ TogetherAI │       │
│  └─────────┘  └───────────┘  └────────────┘       │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## Best Practices

1. **Use automatic selection** unless you have specific requirements
2. **Set cost budgets** to avoid unexpected charges
3. **Monitor performance** to identify issues early
4. **Enable fallback** for critical applications
5. **Use quality priority** for important tasks, cost priority for bulk operations

## References

- [OpenAI API Documentation](https://platform.openai.com/docs)
- [Anthropic API Documentation](https://docs.anthropic.com)
- [Together AI Documentation](https://docs.together.ai)
- [Lux Documentation](https://hexdocs.pm/lux)