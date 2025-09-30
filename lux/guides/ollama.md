# Using Ollama with Lux

Lux ships with first-class support for local models through [Ollama](https://ollama.com/).
This guide walks through configuration, runtime behaviour and a minimal example.

## Prerequisites

1. [Install Ollama](https://ollama.com/download) on the host running your Lux nodes.
2. Ensure the daemon is running (the default listens on `http://localhost:11434`).
3. Optionally pull the models you need ahead of time, e.g. `ollama pull llama3`.

## Configuration

The integration is configurable via environment variables (or the standard
`.envrc` files). The defaults are usually good enough for local development, but
production systems may want tighter limits.

```bash
# .envrc (or dev.envrc) snippet
export OLLAMA_ENDPOINT="http://localhost:11434"
export OLLAMA_MODEL="llama3"
export OLLAMA_MAX_CONCURRENCY=2
export OLLAMA_MODEL_TTL_MS=1800000   # 30 minutes
export OLLAMA_CLEANUP_INTERVAL_MS=600000
export OLLAMA_AUTO_PULL=true
```

The values are read in `config/config.exs` via `Lux.Config.runtime/3`, so they can
be overridden per environment without recompiling.

## Making a request

```elixir
prompt = "Summarise the latest market trends in two bullet points."

{:ok, response} =
  Lux.LLM.Ollama.call(prompt, [], %{
    model: System.get_env("OLLAMA_MODEL", "llama3"),
    options: %{temperature: 0.1}
  })

IO.inspect(response.payload.content)
```

### Tooling

Ollama does not currently expose function-calling APIs. When you pass tools to
`Lux.LLM.Ollama.call/3` they are ignored (the prompt is left untouched) so the
integration behaves predictably compared to providers that support tool calls.

## Model management

Lux keeps a lightweight cache of the models detected on the local Ollama daemon.
When a model is missing and `auto_pull` is enabled, the integration will invoke
`POST /api/pull` automatically. Metadata is stored in ETS and refreshed after the
`model_ttl` expires.

You can inspect the cached metadata at runtime:

```elixir
Lux.LLM.Ollama.ModelManager.cached_models()
# => [%{model: "llama3", digest: "sha256:...", last_used_at: ...}]
```

## Resource controls & telemetry

The `Lux.LLM.Ollama.ResourcePool` enforces a simple global semaphore so that only
`max_concurrency` requests hit Ollama simultaneously. When the pool is drained,
`Lux.LLM.Ollama.call/3` returns `{:error, :busy}` instead of queueing forever.

Every request emits a `[:lux, :ollama, :request]` telemetry span with the model
name and request outcome, making it easy to hook into existing metrics pipelines:

```elixir
:telemetry.attach_many(
  "ollama-logger",
  [[:lux, :ollama, :request, :start], [:lux, :ollama, :request, :stop]],
  fn event, measurements, metadata, _ ->
    Logger.debug("event=#{inspect(event)} status=#{metadata[:status]}")
  end,
  nil
)
```

## Testing locally

Unit tests can rely on `Req.Test` just like the other LLM integrations:

```elixir
Req.Test.expect(Lux.LLM.Ollama.Client, fn conn ->
  assert conn.request_path == "/api/chat"
  Req.Test.json(conn, %{"model" => "llama3", "message" => %{"content" => "hi"}})
end)
```

The default test helper already wires the client so tests run without touching a
real Ollama instance.

## Troubleshooting

- `{:error, :busy}` – increase `OLLAMA_MAX_CONCURRENCY` or retry later.
- `{:error, :model_missing}` – either pull the model manually or set
  `OLLAMA_AUTO_PULL=true`.
- Slow responses – tune `keep_alive` and `options` (`Lux.LLM.Ollama` passes them
  straight to the Ollama API).

With these primitives you can run Lux agents completely offline, experiment with
new models and keep latency tight without incurring hosted LLM costs.
