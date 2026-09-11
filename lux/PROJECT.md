# Project: Universal LLM Provider Abstraction Layer (Spectral-Finance/lux - Bounty #99)

## Architecture
- Common provider behaviour `Lux.LLM.Provider` and configuration structs (`Lux.LLM.ProviderConfig`, `Lux.LLM.ModelConfig`).
- Central GenServer registry `Lux.LLM.ProviderRegistry` for dynamic provider/model registration, lookup, and updates.
- Dynamic Router `Lux.LLM.Router` supporting `:cheapest`, `:smartest`, and capability-based model selection algorithms.
- Smart Fallback Engine `Lux.LLM.Fallback` for transparent redirection on network, 429 Rate Limit, and 503 Service Unavailable errors.
- Telemetry & Cost Tracking module `Lux.LLM.Telemetry` emitting `:telemetry` events and normalizing usage & cost in `Lux.Signal`.
- Google Gemini Provider implementation `Lux.LLM.Gemini` complementing OpenAI, Anthropic, OpenRouter, TogetherAI.
- ExUnit unit test suite in `test/unit/lux/llm/` backed by `UnitAPICase` and `Req.Test`.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Provider Abstraction & Data Schemas | Behaviour `Lux.LLM.Provider`, Structs `ModelConfig`, `ProviderConfig`, and provider adaptations (OpenAI, Gemini, Anthropic, OpenRouter, TogetherAI) | none | DONE |
| 2 | Provider Registry Server | GenServer `Lux.LLM.ProviderRegistry` for dynamic provider and model registration/querying | M1 | DONE |
| 3 | Dynamic Model Router | Selector logic `Lux.LLM.Router` supporting `:cheapest`, `:smartest`, and capability filtering | M1, M2 | DONE |
| 4 | Resilience & Smart Fallback Handling | Engine `Lux.LLM.Fallback` handling 429/503/5xx/network failovers | M1, M2, M3 | DONE |
| 5 | Telemetry, Cost Tracking & Signal Normalization | Monitored execution, token & cost metrics normalization in `Lux.Signal` | M1, M2, M3, M4 | DONE |
| 6 | ExUnit Test Suite & Documentation | Unit tests in `test/unit/lux/llm/` and `@moduledoc` / `@doc` documentation | M1-M5 | DONE |
| 7 | Verification & Forensic Audit | Verification via Reviewer, Challenger, and Forensic Auditor | M6 | DONE |

## Interface Contracts
### `Lux.LLM.Provider`
- `@callback id() :: atom()`
- `@callback models() :: [Lux.LLM.ModelConfig.t()]`
- `@callback call(prompt :: String.t(), tools :: list(), opts :: map() | keyword()) :: {:ok, Lux.Signal.t()} | {:error, term()}`

### `Lux.LLM.ProviderRegistry`
- `start_link(opts)`
- `register_provider(provider_module, opts)`
- `unregister_provider(provider_id)`
- `list_providers()`
- `list_models(opts)`
- `get_provider(provider_id)`

### `Lux.LLM.Router`
- `select_model(criteria :: map() | atom(), opts :: keyword()) :: {:ok, {provider_module, model_config}} | {:error, term()}`
- Criteria options: `:cheapest`, `:smartest`, `%{capabilities: [...], max_cost_per_1k: float()}`

### `Lux.LLM.Fallback`
- `call_with_fallback(primary_spec, prompt, tools, opts, fallback_specs)`

## Code Layout
- `lib/lux/llm/provider.ex`: Provider behaviour and struct definitions
- `lib/lux/llm/provider_registry.ex`: GenServer registry
- `lib/lux/llm/router.ex`: Dynamic model selection algorithms
- `lib/lux/llm/fallback.ex`: Smart fallback execution engine
- `lib/lux/llm/telemetry.ex`: Telemetry and cost tracking
- `lib/lux/llm/gemini.ex`: Gemini LLM provider implementation
- `lib/lux/llm/open_ai.ex`, `anthropic.ex`, `open_router.ex`, `together_ai.ex`: Standardized provider adapters
- `test/unit/lux/llm/provider_registry_test.exs`
- `test/unit/lux/llm/router_test.exs`
- `test/unit/lux/llm/fallback_test.exs`
- `test/unit/lux/llm/telemetry_test.exs`
