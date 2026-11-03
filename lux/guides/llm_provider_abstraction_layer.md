# LLM Provider Abstraction Layer in Lux

The LLM Provider Abstraction Layer provides a unified, production-grade interface to manage diverse LLM providers, dynamically route prompts according to operational goals (cost, latency, reasoning depth, privacy), execute automated multi-provider fallbacks, track token spending against budgets, and cache deterministic responses.

---

## 1. Architectural Overview

```
+-------------------------------------------------------------------------+
|                              Agent / Beam                               |
+------------------------------------+------------------------------------+
                                     |
                                     v
+-------------------------------------------------------------------------+
|                  Universal LLM Pipeline Orchestrator                    |
|                                                                         |
|  1. Cache Check  -->  2. Model Router  -->  3. Fallback Engine  --> 4. Cost Tracker  |
+------------------------------------+------------------------------------+
                                     |
        +----------------------------+----------------------------+
        |                            |                            |
        v                            v                            v
+---------------+            +---------------+            +---------------+
|    OpenAI     |            |   Anthropic   |            |  Ollama (Local)|
|    (GPT-4o)   |            | (Claude 3.5)  |            |   (Llama 3.2)  |
+---------------+            +---------------+            +---------------+
        |                            |                            |
        v                            v                            v
+---------------+            +---------------+            +---------------+
|  Together AI  |            |  OpenRouter   |            |  Perplexity   |
|  (OpenSource) |            |  (Multi-LLM)  |            |   (Search)    |
+---------------+            +---------------+            +---------------+
```

---

## 2. Universal Provider Behaviour (`Lux.LLM.Provider`)

All LLM integrations conform to the `Lux.LLM.Provider` behaviour:

```elixir
defmodule Lux.LLM.Provider do
  @callback call(prompt :: String.t(), tools :: list(), options :: map()) ::
              {:ok, Lux.LLM.Response.t()} | {:error, term()}
  @callback list_models() :: [map()]
  @callback calculate_cost(prompt_tokens :: integer(), completion_tokens :: integer(), model :: String.t()) :: float()
  @callback health_check() :: :ok | {:error, term()}
end
```

---

## 3. Provider Registry (`Lux.LLM.Registry`)

Providers register metadata including model endpoints, capabilities (`:tool_calling`, `:streaming`, `:vision`, `:local`), and cost tiers:

```elixir
# Inspect enabled providers
providers = Lux.LLM.Registry.list_enabled_providers()

# Query providers by capability
local_llms = Lux.LLM.Registry.filter_by_capability(:local)
tool_llms = Lux.LLM.Registry.filter_by_capability([:tool_calling, :streaming])

# Dynamic enabling / disabling
Lux.LLM.Registry.disable_provider(:openai)
Lux.LLM.Registry.enable_provider(:openai)
```

---

## 4. Automatic Model Selection (`Lux.LLM.Router`)

The Router selects the optimal provider based on execution strategy:

- `:cost_optimized` - Selects free (Ollama) or low-cost economy models.
- `:reasoning_quality` - Routes to frontier models (Claude 3.5 Sonnet, GPT-4o, o1).
- `:offline_privacy` - Routes strictly to on-premise local models (Ollama).
- `:research` - Routes to web-search-augmented models (Perplexity Sonar).
- `:performance` - Prioritizes low-latency generation.

```elixir
{:ok, selection} = Lux.LLM.Router.select_provider(%{
  strategy: :cost_optimized,
  require_tools: true
})

# Result:
# %{provider_id: :together_ai, model: "meta-llama/...", cost_tier: :economy}
```

---

## 5. Resilient Multi-Provider Fallback (`Lux.LLM.FallbackManager`)

If a primary provider fails with rate limits (HTTP 429), timeouts, or outages, `FallbackManager` transparently redirects to secondary and tertiary providers:

```elixir
{:ok, response, metadata} = Lux.LLM.FallbackManager.execute_with_fallback(
  "Analyze this market data...",
  [],
  %{fallback_chain: [:openai, :anthropic, :together_ai]}
)

# metadata.successful_provider => :anthropic
# metadata.attempts_count => 2
```

---

## 6. Cost Tracking & Budget Auditing (`Lux.LLM.CostTracker`)

`Lux.LLM.CostTracker` calculates real-time USD expenditures and enforces operational ceilings:

```elixir
# Record token consumption
Lux.LLM.CostTracker.record_usage(:openai, "gpt-4o", 1200, 350)

# Check budget threshold ($25.00 USD)
case Lux.LLM.CostTracker.check_budget_limit(25.0) do
  {:ok, :within_budget, current_spend} ->
    Logger.info("Current spend: $#{current_spend}")

  {:exceeded, current_spend, limit} ->
    Logger.warning("Budget exceeded: $#{current_spend} > $#{limit}")
end
```

---

## 7. Deterministic Prompt Caching (`Lux.LLM.Cache`)

Avoid redundant API costs for repeated deterministic tasks:

```elixir
key = Lux.LLM.Cache.generate_key("System prompt...", "gpt-4o")

case Lux.LLM.Cache.get(key) do
  {:ok, cached_response} ->
    # Return immediately without network call
    cached_response

  :miss ->
    # Fetch from provider and populate cache
    Lux.LLM.Cache.put(key, response, 3600)
end
```

---

## 8. Dedicated Prisms

- **`Lux.Prisms.LLM.ModelSelectPrism`**: Analyzes strategies and yields the best provider.
- **`Lux.Prisms.LLM.ProviderCallPrism`**: Direct invocation through a target provider.
- **`Lux.Prisms.LLM.FallbackPrism`**: Invocations with automatic failover.
- **`Lux.Prisms.LLM.CostAnalyticsPrism`**: Usage logging, cost reporting, and budget checks.
- **`Lux.Prisms.LLM.CachePrism`**: Content-addressable cache read/write operations.

---

## 9. Pipeline Orchestration Beam

Run the full end-to-end pipeline in Lux agents:

```elixir
{:ok, result} = Lux.Beams.LLM.UniversalLLMPipelineBeam.run(%{
  prompt: "Synthesize quarterly portfolio metrics",
  strategy: "reasoning_quality",
  require_tools: true
})
```
