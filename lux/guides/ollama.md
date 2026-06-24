# Ollama LLM Provider

Lux can use [Ollama](https://ollama.com/) for local, self-hosted LLM inference through
`Lux.LLM.Ollama`. This is useful for private development, offline workflows, and agents
that should avoid hosted model APIs.

## Requirements

Install Ollama and pull a model:

```bash
ollama pull llama3.2
```

Ollama serves its local API at `http://localhost:11434` by default.

## Basic Usage

```elixir
{:ok, response} =
  Lux.LLM.Ollama.call("Return a JSON object with a greeting", [], %{
    model: "llama3.2"
  })

response.payload.content
```

By default, `Lux.LLM.Ollama` asks Ollama for JSON output and returns the same
`Lux.LLM.ResponseSignal` shape used by other Lux chat providers.

## Tools

Lux tools can be passed directly as Prisms, Beams, or Lenses:

```elixir
{:ok, response} =
  Lux.LLM.Ollama.call("Use the weather tool", [MyApp.WeatherLens], %{
    model: "llama3.2"
  })
```

Tool definitions are sent to Ollama using its `tools` chat API format. Tool calls returned
by Ollama are executed through Lux and included in `response.payload.tool_calls_results`.

## Model Management

Ollama stores pulled models locally. Lux exposes helpers for common model operations:

```elixir
{:ok, models} = Lux.LLM.Ollama.list_models()
{:ok, true} = Lux.LLM.Ollama.model_available?("llama3.2")
{:ok, :cached} = Lux.LLM.Ollama.ensure_model("llama3.2")
{:ok, info} = Lux.LLM.Ollama.show_model("llama3.2")
```

To pull a missing model:

```elixir
{:ok, _} = Lux.LLM.Ollama.pull_model("llama3.2")
```

You can also make `call/3` pull a missing model automatically:

```elixir
Lux.LLM.Ollama.call("Hello", [], %{
  model: "llama3.2",
  auto_pull: true
})
```

## Resource Controls

Ollama runtime options can be set from the provider config:

```elixir
Lux.LLM.Ollama.call("Summarize this", [], %{
  model: "llama3.2",
  temperature: 0.2,
  max_tokens: 512,
  num_ctx: 4096,
  num_thread: 4,
  keep_alive: "10m"
})
```

Supported controls include `temperature`, `top_p`, `top_k`, `max_tokens`, `seed`,
`num_ctx`, `num_gpu`, `num_thread`, and `keep_alive`.

## Performance Metadata

Ollama timing and token counters are available in response metadata:

```elixir
response.metadata.usage
response.metadata.performance
```

The metadata includes prompt/completion token counts when Ollama returns them, duration
counters, and an estimated `tokens_per_second`.

## Custom Endpoint

Use `base_url` for a custom Ollama host:

```elixir
Lux.LLM.Ollama.call("Hello", [], %{
  base_url: "http://ollama.internal:11434",
  model: "llama3.2"
})
```
