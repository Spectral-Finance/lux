# Project Plan: Lux - OpenRouter API Integration (Bounty #95)

## Architecture
- Framework: Spectral-Finance/lux (Elixir)
- Location of Mix package: `/home/Konor1743/Operacion Dolar/lux/lux`
- Provider module: `Lux.LLM.OpenRouter` in `lux/lib/lux/llm/open_router.ex` & `lib/lux/llm/open_router.ex`
- Test module: `Lux.LLM.OpenRouterTest` in `lux/test/unit/lux/llm/open_router_test.exs`, `lux/test/lux/llm/open_router_test.exs`, & `test/lux/llm/open_router_test.exs`
- Response type: `Lux.LLM.ResponseSignal` (Signal wrapping payload with `content`, `model`, `finish_reason`, `tool_calls`, `tool_calls_results` and metadata containing `usage` with `prompt_tokens`, `completion_tokens`, `total_tokens`).

## Milestones

| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Exploration & Architecture | Investigate codebase patterns, OpenAI provider, ResponseSignal format, Req testing mocks | None | DONE |
| 2 | Implementation | Implement `Lux.LLM.OpenRouter` (`open_router.ex`), update config & test setup, and create test suite (`open_router_test.exs`) | M1 | DONE |
| 3 | Review, Challenge & Audit | Perform high-reliability code review, test suite execution, adversarial test checks, and forensic audit | M2 | DONE |

## Requirements Matrix & Mapping

| Req ID | Requirement Description | Implementation Target | Verification Method |
|--------|------------------------|-----------------------|---------------------|
| R1 | Native Elixir module `Lux.LLM.OpenRouter` implementing `Lux.LLM` behaviour and returning `Lux.LLM.ResponseSignal` | `lux/lib/lux/llm/open_router.ex` | Unit test checking behaviour compliance & signal structure |
| R2 | OpenAI compatibility with optional headers (`HTTP-Referer`, `X-OpenRouter-Title`) and dynamic model slugs | `lux/lib/lux/llm/open_router.ex` | Mock HTTP tests verifying request headers & model body param |
| R3 | Extract token statistics (`prompt_tokens`, `completion_tokens`, `total_tokens`) into telemetry/metadata | `lux/lib/lux/llm/open_router.ex` | Mock HTTP tests verifying metadata.usage structure |
| R4 | Unit & mock integration test suite in `test/lux/llm/open_router_test.exs` with 100% PASS rate | `lux/test/unit/lux/llm/open_router_test.exs` | ExUnit test execution & verification |
