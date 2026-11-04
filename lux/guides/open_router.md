# OpenRouter Integration in Lux

`Lux.LLM.OpenRouter` integrates OpenRouter (`https://openrouter.ai/api/v1/chat/completions`) into Lux, providing unified access to OpenAI, Anthropic, Meta Llama, DeepSeek, and Mistral models with automatic fallback routing, rate-limit retries, tool calling, and cost estimation (`Spectral-Finance/lux#95`).

## Configuration & Usage

```elixir
alias Lux.LLM.OpenRouter

{:ok, signal} =
  OpenRouter.call(
    "Evaluate liquidity depth on Base USDC pools",
    [],
    %{
      model: "anthropic/claude-3.5-sonnet",
      fallback_models: ["openai/gpt-4o", "meta-llama/llama-3.1-70b-instruct"],
      api_key: System.get_env("OPENROUTER_API_KEY"),
      max_retries: 2
    }
  )
```
