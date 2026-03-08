# OpenRouter Integration

OpenRouter provides access to 200+ LLM models through a single unified API,
including models from OpenAI, Anthropic, Google, Meta, Mistral, and more.

## Setup

Add your OpenRouter API key to the configuration:

```elixir
config :lux, :api_keys, openrouter: "sk-or-v1-..."
config :lux, :open_router_models, default: "anthropic/claude-sonnet-4-20250514"
```

## Basic Usage

```elixir
{:ok, signal} = Lux.LLM.OpenRouter.call(
  "Explain quantum computing in simple terms",
  [],
  %{api_key: "sk-or-v1-..."}
)

IO.puts(signal.payload.content)
```

## Model Selection

OpenRouter supports 200+ models. Use the `model` parameter:

```elixir
# Anthropic Claude
Lux.LLM.OpenRouter.call("Hello", [], %{model: "anthropic/claude-sonnet-4-20250514"})

# OpenAI GPT-4
Lux.LLM.OpenRouter.call("Hello", [], %{model: "openai/gpt-4-turbo"})

# Meta Llama
Lux.LLM.OpenRouter.call("Hello", [], %{model: "meta-llama/llama-3-70b-instruct"})

# Google Gemini
Lux.LLM.OpenRouter.call("Hello", [], %{model: "google/gemini-pro-1.5"})

# Mistral
Lux.LLM.OpenRouter.call("Hello", [], %{model: "mistralai/mixtral-8x7b-instruct"})
```

## Listing Available Models

```elixir
{:ok, models} = Lux.LLM.OpenRouter.list_models()

Enum.each(models, fn model ->
  IO.puts("#{model["id"]} - #{model["name"]} ($#{model["pricing"]["prompt"]}/token)")
end)
```

## Tool Usage

OpenRouter supports tool calling for compatible models:

```elixir
defmodule MyPrism do
  use Lux.Prism,
    name: "calculator",
    description: "Performs calculations",
    input_schema: %{
      type: :object,
      properties: %{expression: %{type: :string}},
      required: ["expression"]
    }

  def handler(%{"expression" => expr}, _ctx) do
    {:ok, %{result: Code.eval_string(expr) |> elem(0)}}
  end
end

{:ok, signal} = Lux.LLM.OpenRouter.call(
  "What is 42 * 17?",
  [MyPrism],
  %{model: "openai/gpt-4-turbo"}
)
```

## Provider Preferences

Control which providers serve your requests:

```elixir
Lux.LLM.OpenRouter.call("Hello", [], %{
  model: "anthropic/claude-sonnet-4-20250514",
  provider: %{
    # Prefer Anthropic direct, fall back to others
    order: ["Anthropic"],
    allow_fallbacks: true,
    # Only use providers that support all parameters
    require_parameters: true
  }
})
```

## Transforms

Use middleware transforms for prompt optimization:

```elixir
Lux.LLM.OpenRouter.call("Hello", [], %{
  model: "openai/gpt-4",
  # "middle-out" compresses long prompts to fit context
  transforms: ["middle-out"]
})
```

## Cost Tracking

Response metadata includes cost information:

```elixir
{:ok, signal} = Lux.LLM.OpenRouter.call("Hello", [], %{api_key: key})

# Token usage
IO.inspect(signal.metadata.usage)

# Cost (when available)
IO.inspect(signal.metadata[:cost])

# Generation ID for detailed cost lookup
IO.inspect(signal.metadata[:generation_id])
```

Get detailed cost data for a generation:

```elixir
{:ok, stats} = Lux.LLM.OpenRouter.get_generation_stats("gen-abc123", api_key: key)
IO.inspect(stats)
```

## Error Handling

The provider handles common error scenarios:

```elixir
case Lux.LLM.OpenRouter.call("Hello", [], config) do
  {:ok, signal} ->
    # Success
    signal.payload.content

  {:error, :invalid_api_key} ->
    # Invalid or missing API key
    "Check your API key"

  {:error, :insufficient_credits} ->
    # Account has no credits
    "Add credits at openrouter.ai"

  {:error, :max_retries_exceeded} ->
    # Failed after 3 retries (rate limit, timeout, upstream errors)
    "Service temporarily unavailable"

  {:error, {status, message}} ->
    # Other API error
    "Error #{status}: #{message}"
end
```

## Retry Behavior

OpenRouter provider includes automatic retry with exponential backoff for:

- **429 Rate Limited** — respects `Retry-After` header
- **408 Timeout** — retries up to 3 times
- **502/503 Upstream Errors** — retries with backoff
- **Network Errors** — retries with backoff

Maximum 3 retries with exponential backoff (1s, 2s, 4s base delays).

## Site Identification

Register your app with OpenRouter for analytics:

```elixir
Lux.LLM.OpenRouter.call("Hello", [], %{
  site_url: "https://myapp.com",
  site_name: "My Application"
})
```

## Configuration Reference

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `model` | string | `"openai/gpt-4"` | Model identifier |
| `api_key` | string | from config | OpenRouter API key |
| `temperature` | float | 0.7 | Sampling temperature |
| `max_tokens` | integer | nil | Maximum response tokens |
| `json_response` | boolean | true | Request JSON output |
| `json_schema` | map | nil | JSON schema for structured output |
| `provider` | map | nil | Provider routing preferences |
| `transforms` | list | nil | Middleware transforms |
| `route` | string | nil | Routing strategy |
| `site_url` | string | nil | Your app URL |
| `site_name` | string | nil | Your app name |
| `receive_timeout` | integer | 120000 | Request timeout in ms |
