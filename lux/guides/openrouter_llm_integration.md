# OpenRouter LLM Integration Guide

This guide covers the integration of OpenRouter into the Lux framework, providing access to dozens of state-of-the-art models (Anthropic Claude, OpenAI GPT-4o, Meta Llama 3.1, Google Gemini, DeepSeek, Mistral) through a single unified interface with dynamic model routing, automated fallback cascades, quota management, and token cost tracking.

---

## 1. Overview & Architecture

OpenRouter acts as a unified router and clearinghouse for large language models, providing consistent pricing, standardized APIs, and resilience against upstream provider outages.

```
+-----------------------------------------------------------------------+
|                              Lux Agent                                |
+-----------------------------------------------------------------------+
                                   |
                                   v
             +-------------------------------------------+
             | Lux.Beams.Llm.OpenRouter.InferenceBeam    |
             +-------------------------------------------+
               /                 |                     \
              v                  v                      v
    +-------------------+ +-------------------+ +-------------------+
    | ModelRoutePrism   | | FallbackPrism     | | CostPrism         |
    | (Dynamic Choice)  | | (Cascade Try)     | | (Budget & Tokens) |
    +-------------------+ +-------------------+ +-------------------+
                                   |
                                   v
             +-------------------------------------------+
             | Lux.LLM.OpenRouter (Behaviour: Lux.LLM)   |
             | - HTTP-Referer & X-Title Attribution      |
             | - Native Multi-Model Fallbacks (`models`) |
             | - Auto Retries with Exponential Backoff   |
             +-------------------------------------------+
                                   |
                                   v
             +-------------------------------------------+
             | OpenRouter API (https://openrouter.ai)    |
             |  /api/v1/chat/completions                 |
             |  /api/v1/models                           |
             |  /api/v1/auth/key                         |
             +-------------------------------------------+
```

---

## 2. Configuration

### Environment Variables

Configure your OpenRouter API key in `.envrc` or system environment:

```bash
export OPENROUTER_API_KEY="sk-or-v1-..."
```

### Application Config

In `config/config.exs`:

```elixir
config :lux, :openrouter_models,
  default: "anthropic/claude-3.5-sonnet",
  cheapest: "meta-llama/llama-3.1-8b-instruct:free",
  smartest: "anthropic/claude-3.5-sonnet",
  fastest: "google/gemini-2.0-flash",
  balanced: "openai/gpt-4o-mini"
```

In `config/runtime.exs`:

```elixir
config :lux, :api_keys,
  openrouter: env!("OPENROUTER_API_KEY", :string!, "missing openrouter")
```

---

## 3. Core Modules

### 3.1 `Lux.LLM.OpenRouter`

Implements the standard `Lux.LLM` behaviour.

```elixir
# Basic call
{:ok, signal} = Lux.LLM.OpenRouter.call("Analyze the protocol risk", [], %{
  model: "anthropic/claude-3.5-sonnet",
  temperature: 0.5
})

IO.puts(signal.payload.content)
IO.inspect(signal.metadata.usage)
IO.inspect(signal.metadata.cost_estimate)
```

#### Tool Calling with Beams & Prisms

Like other Lux LLM adapters, you can provide Beams, Prisms, and Lenses directly as tools:

```elixir
tools = [
  MyApp.TokenPricePrism,
  MyApp.ExecuteTradeBeam
]

{:ok, signal} = Lux.LLM.OpenRouter.call("What is the current ETH price?", tools, %{
  model: "openai/gpt-4o"
})
```

#### Native Multi-Model Fallbacks

OpenRouter supports server-side fallback cascades by specifying an ordered list of models:

```elixir
{:ok, signal} = Lux.LLM.OpenRouter.call("High priority query", [], %{
  model: "anthropic/claude-3.5-sonnet",
  models: [
    "anthropic/claude-3.5-sonnet",
    "openai/gpt-4o",
    "meta-llama/llama-3.1-70b-instruct"
  ],
  route: "fallback"
})
```

---

### 3.2 `Lux.LLM.OpenRouter.ModelRouter`

Selects models programmatically and estimates costs:

```elixir
alias Lux.LLM.OpenRouter.ModelRouter

# Select model by strategy
smart_model = ModelRouter.select_model(strategy: :smartest)
# => "anthropic/claude-3.5-sonnet"

cheap_model = ModelRouter.select_model(strategy: :cheapest)
# => "deepseek/deepseek-chat"

free_model = ModelRouter.select_model(strategy: :free)
# => "meta-llama/llama-3.1-8b-instruct:free"

# Calculate estimated cost
cost = ModelRouter.estimate_cost("anthropic/claude-3.5-sonnet", 10_000, 2_000)
# => %{prompt_cost: 0.03, completion_cost: 0.03, total_cost: 0.06}
```

---

### 3.3 `Lux.LLM.OpenRouter.KeyLimits`

Queries the OpenRouter `/api/v1/auth/key` endpoint:

```elixir
alias Lux.LLM.OpenRouter.KeyLimits

{:ok, info} = KeyLimits.get_key_info()

IO.puts("Key label: #{info.label}")
IO.puts("Spent so far: $#{info.usage}")
IO.puts("Credits remaining: #{info.credits_remaining}")
IO.puts("Rate limit: #{info.rate_limit_requests} requests per #{info.rate_limit_interval}")
```

---

## 4. Dedicated Prisms

### `Lux.Prisms.Llm.OpenRouter.ChatPrism`
Direct invocation prism with parameter formatting:

```elixir
{:ok, result} = Lux.Prisms.Llm.OpenRouter.ChatPrism.handler(%{
  "prompt" => "Summarize market movements",
  "model" => "openai/gpt-4o-mini",
  "temperature" => 0.7
}, %{})
```

### `Lux.Prisms.Llm.OpenRouter.ModelRoutePrism`
Computes the optimal model and fallback chain given requirements:

```elixir
{:ok, route} = Lux.Prisms.Llm.OpenRouter.ModelRoutePrism.handler(%{
  "strategy" => "fastest",
  "min_context" => 64_000
}, %{})

# Returns %{selected_model: "google/gemini-2.0-flash", fallback_chain: [...], ...}
```

### `Lux.Prisms.Llm.OpenRouter.CostPrism`
Tracks tokens, computes costs, and asserts budget limits:

```elixir
{:ok, cost} = Lux.Prisms.Llm.OpenRouter.CostPrism.handler(%{
  "model" => "anthropic/claude-3.5-sonnet",
  "prompt_tokens" => 4_000,
  "completion_tokens" => 800,
  "budget_limit" => 0.05
}, %{})

# Returns %{total_cost: 0.024, budget_exceeded: false, remaining_budget: 0.026}
```

### `Lux.Prisms.Llm.OpenRouter.FallbackPrism`
Client-side resilience cascading:

```elixir
{:ok, result} = Lux.Prisms.Llm.OpenRouter.FallbackPrism.handler(%{
  "prompt" => "Generate risk assessment",
  "models" => ["anthropic/claude-3.5-sonnet", "openai/gpt-4o", "meta-llama/llama-3.1-70b-instruct"]
}, %{})
```

---

## 5. End-to-End Inference Beam

The `Lux.Beams.Llm.OpenRouter.OpenRouterInferenceBeam` ties everything together into a self-contained, auditable pipeline:

```elixir
{:ok, result, log} = Lux.Beams.Llm.OpenRouter.OpenRouterInferenceBeam.run(%{
  prompt: "Synthesize liquidity pool health on Arbitrum",
  strategy: "smartest",
  budget_limit: 0.10
})

IO.puts("Answer: #{result.content}")
IO.puts("Model Used: #{result.model_used}")
IO.puts("Total Cost: $#{result.total_cost}")
```

---

## 6. Testing

All components include comprehensive ExUnit test coverage:

```bash
# Run all OpenRouter tests
mix test test/unit/lux/llm/open_router_test.exs
mix test test/unit/lux/prisms/llm/open_router_prisms_test.exs
mix test test/unit/lux/beams/llm/open_router_beam_test.exs
```
