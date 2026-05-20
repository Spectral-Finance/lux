# OpenRouter Integration

Lux includes a dedicated OpenRouter client at `Lux.LLM.OpenRouter`.

## Configuration

Set your API key in the environment:

```bash
export OPENROUTER_API_KEY=sk-or-...
```

You can also pass `api_key: "..."` per request.

## Chat completions

```elixir
{:ok, response} =
  Lux.LLM.OpenRouter.chat([
    %{role: "system", content: "You are concise."},
    %{role: "user", content: "Explain Lux in one sentence."}
  ], model: "openai/gpt-4o-mini")
```

`chat/2`, `completion/2`, and `generate/2` are aliases for provider-style usage. Use `complete/2` for a single prompt string.

## Model selection and fallbacks

OpenRouter model IDs are passed directly. The client retries transient errors and can move through a local fallback list:

```elixir
Lux.LLM.OpenRouter.chat(messages,
  model: "anthropic/claude-3.5-sonnet",
  fallbacks: ["openai/gpt-4o", "google/gemini-pro"],
  retries: 2
)
```

You can also pass `models: [...]` to define the full ordered model list.

## Provider routing options

OpenRouter-specific routing options are forwarded in the request body:

```elixir
Lux.LLM.OpenRouter.chat(messages,
  model: :auto,
  provider: %{
    sort: "price",
    allow_fallbacks: true,
    require_parameters: true,
    quantizations: ["bf16", "fp8"]
  },
  transforms: ["middle-out"],
  cache_control: %{type: "ephemeral"}
)
```

Common OpenAI-compatible options such as `temperature`, `max_tokens`, `top_p`, `tools`, `tool_choice`, `response_format`, and `stop` are also supported.

## JSON responses

```elixir
Lux.LLM.OpenRouter.chat(messages,
  model: "openai/gpt-4o-mini",
  json_response: true
)
```

For structured output, pass `json_schema: %{...}`.

## Cost metadata

Successful responses are annotated with Lux metadata:

```elixir
response["lux"]["cost"]
```

If OpenRouter returns a usage cost, that value is used. Otherwise Lux estimates cost for bundled known models and reports `"source" => "estimated"`.
