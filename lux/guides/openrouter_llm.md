# OpenRouter Integration

`Lux.LLM.OpenRouter` connects Lux agents to multiple LLM providers (`anthropic/claude-3.5-sonnet`, `openai/gpt-4o`, `meta-llama/llama-3.3-70b-instruct`, `deepseek/deepseek-r1`, `google/gemini-2.0-flash-001`) through a single unified interface.

## Features
- **Fallback Routing**: Automatically populates `models` and `route: "fallback"` for zero-downtime provider failover.
- **Rate Limiting & Budget Quotas**: `QuotaTracker` prevents runaway API spend.
- **Retries**: Exponential backoff on HTTP `429`, `502`, `503`, and `504`.
