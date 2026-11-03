# Universal LLM Provider Abstraction Layer Guide

## Overview

The `Lux.LLM` abstraction suite provides universal multi-provider orchestration, intelligent model selection, automated fallback cascades, token cost accounting, and prompt caching across leading LLM providers (OpenAI, Anthropic, Together AI, and Groq).

---

## Architectural Components

1. **`Lux.LLM.ProviderRegistry`**
   - Registry for supported providers, active models, capabilities (`:tools`, `:vision`, `:structured_output`), and operational latency metrics.

2. **`Lux.LLM.ModelSelector`**
   - Discovers optimal models according to goal constraints:
     - `:cost_optimized` (`gpt-4o-mini`, `claude-3-5-haiku`)
     - `:latency_optimized` (`llama-3.3-70b-versatile` on Groq)
     - `:reasoning_optimized` (`o1`, `claude-3-5-sonnet`)
     - `:balanced` (`gpt-4o`)

3. **`Lux.LLM.FallbackChain`**
   - Cascades failed inference attempts across an ordered provider chain.
   - Automatically recovers from HTTP 429 rate limits, 5xx server issues, or network timeouts.

4. **`Lux.LLM.CostTracker`**
   - Real-time token usage cost calculations based on per-million token rates:
     $$\text{Cost} = \frac{\text{Prompt Tokens} \times \text{Input Rate} + \text{Completion Tokens} \times \text{Output Rate}}{10^6}$$

5. **`Lux.LLM.Optimizer`**
   - Cleans prompt whitespace, minifies payload, estimates tokens, and generates deterministic SHA-256 prompt cache keys.

---

## Prisms

- `Lux.Prisms.Llm.ModelSelectorPrism`: Selects best model according to constraints.
- `Lux.Prisms.Llm.FallbackChainPrism`: Formulates prioritized failover order.
- `Lux.Prisms.Llm.CostTrackerPrism`: Calculates USD costs from prompt and completion token counts.
- `Lux.Prisms.Llm.ProviderHealthPrism`: Reports provider health and latency metrics.
- `Lux.Prisms.Llm.PromptOptimizerPrism`: Trims prompts and generates deterministic cache keys.

---

## Beam Workflow

`Lux.Beams.Llm.LlmInferenceBeam` coordinates:
1. Minifies and analyzes prompt via `PromptOptimizerPrism`.
2. Selects optimal model via `ModelSelectorPrism`.
3. Pre-calculates token expenditure via `CostTrackerPrism`.

---

## Quickstart

```elixir
# 1. Select cost-optimized model
{:ok, model} = Lux.Prisms.Llm.ModelSelectorPrism.run(%{
  strategy: "cost_optimized"
})

# 2. Track token cost
{:ok, cost} = Lux.Prisms.Llm.CostTrackerPrism.run(%{
  model: model.model,
  prompt_tokens: 4500,
  completion_tokens: 400
})

# 3. Coordinate workflow via LlmInferenceBeam
{:ok, result} = Lux.Beams.Llm.LlmInferenceBeam.run(%{
  user_prompt: "Explain zero knowledge proofs in simple terms.",
  strategy: "cost_optimized"
})
```
