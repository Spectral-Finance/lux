# LLM Provider Abstraction Layer

Lux provides a unified, extensible abstraction layer for working with multiple LLM providers (`OpenAI`, `Anthropic`, `Together AI`, `Mira Network`, and custom providers) with automatic model selection, smart fallback handling, response caching, and cost/latency telemetry.

## Core Modules

- `Lux.LLM`: Unified interface (`call/3`, `call_smart/3`, `list_providers/0`)
- `Lux.LLM.ProviderRegistry`: Dynamic provider and model catalog with health status management
- `Lux.LLM.ModelSelector`: Capability-, complexity-, latency-, and cost-aware automatic model selector
- `Lux.LLM.FallbackHandler`: Ordered multi-provider failover and health-state tracking
- `Lux.LLM.TelemetryAndCache`: SHA-256 deterministic response caching and token cost/latency analytics

## Usage Examples

```elixir
# Automatic model selection + caching + multi-provider fallback
{:ok, response} =
  Lux.LLM.call_smart("Summarize market liquidity on Base", [], %{
    complexity: :medium,
    optimize_for: :cost,
    required_capabilities: [:tool_use],
    fallback_providers: [:anthropic, :together_ai]
  })

# Inspect live cost and latency telemetry
metrics = Lux.LLM.TelemetryAndCache.get_metrics()
```
