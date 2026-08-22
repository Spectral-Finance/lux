# Context & Background: Lux OpenRouter API Integration (Bounty #95)

## Overview
OpenRouter is an AI model aggregator supporting OpenAI-compatible chat completion endpoints with specific headers (`HTTP-Referer`, `X-OpenRouter-Title`) and model slug conventions (e.g. `~openai/gpt-latest` or `anthropic/claude-3.5-sonnet`).

## Codebase Context
- Framework: `lux` (Elixir framework for LLM-powered agent workflows)
- Root Elixir App path: `/home/Konor1743/Operacion Dolar/lux/lux`
- Relevant Modules:
  - `Lux.LLM` (`lib/lux/llm.ex`)
  - `Lux.LLM.ResponseSignal` (`lib/lux/llm/response_signal.ex`)
  - `Lux.LLM.OpenAI` (`lib/lux/llm/open_ai.ex`)
  - `Lux.LLM.TogetherAI` (`lib/lux/llm/together_ai.ex`)
  - `Lux.LLM.Anthropic` (`lib/lux/llm/anthropic.ex`)

## Key Technical Specifications for `Lux.LLM.OpenRouter`
1. Endpoint: `https://openrouter.ai/api/v1/chat/completions` (default, configurable)
2. Config Struct `Lux.LLM.OpenRouter.Config`:
   - `endpoint`: string, default "https://openrouter.ai/api/v1/chat/completions"
   - `model`: string, default e.g. "openai/gpt-4o" or Application config default
   - `api_key`: string, resolved via `Lux.Config.resolve/1`
   - `site_url`: string or nil (maps to `HTTP-Referer` header if present)
   - `site_name`: string or nil (maps to `X-OpenRouter-Title` header if present)
   - `temperature`, `max_tokens`, `messages`, `json_response`, `json_schema`, `tool_choice`
3. Headers:
   - Authorization: "Bearer <api_key>"
   - Content-Type: "application/json"
   - HTTP-Referer: optional, sent when site_url (or HTTP-Referer config) is set
   - X-OpenRouter-Title: optional, sent when site_name (or X-OpenRouter-Title config) is set
4. Token Extraction:
   - API response body contains `"usage" => %{"prompt_tokens" => ..., "completion_tokens" => ..., "total_tokens" => ...}`
   - `metadata.usage` in `ResponseSignal` must contain this map.
5. Response:
   - Returns `{:ok, %Lux.Signal{schema_id: Lux.LLM.ResponseSignal, payload: payload, metadata: metadata}}` or `{:error, reason}`.
