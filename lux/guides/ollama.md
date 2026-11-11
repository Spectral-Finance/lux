# Local Model Support with Ollama

Lux natively supports running local Large Language Models (LLMs) and embedding models via [Ollama](https://ollama.com) using `Lux.LLM.Ollama` and `Lux.LLM.Ollama.ModelManager`.

## Prerequisites

1. Install Ollama from [ollama.com](https://ollama.com):
   ```bash
   curl -fsSL https://ollama.com/install.sh | sh
   ```
2. Pull a local model:
   ```bash
   ollama pull llama3.2
   ollama pull nomic-embed-text
   ```

## Configuration

Configure your Ollama endpoint and default models in `config/runtime.exs` or via environment variables:

```bash
export OLLAMA_ENDPOINT="http://localhost:11434"
export OLLAMA_DEFAULT_MODEL="llama3.2"
```

When configuring an Agent or calling `Lux.LLM` directly, pass `provider: :ollama` (or `Lux.LLM.Ollama`):

```elixir
Lux.LLM.call(
  "Explain zero-knowledge proofs in two sentences.",
  [],
  %{
    provider: Lux.LLM.Ollama,
    model: "llama3.2",
    temperature: 0.3,
    num_ctx: 8192,
    num_gpu: 1,
    keep_alive: "10m"
  }
)
```

## Tool Calling (`Beam`, `Prism`, `Lens`)

`Lux.LLM.Ollama` translates `Lux.Beam`, `Lux.Prism`, and `Lux.Lens` definitions into Ollama function-calling schemas:

```elixir
Lux.LLM.Ollama.call(
  "Fetch the current ETH price using the price lens",
  [MyApp.Lenses.EthPriceLens],
  %{model: "llama3.2", temperature: 0.0}
)
```

## Model Management & Telemetry

Use `Lux.LLM.Ollama.ModelManager` to inspect, pull, cache, and monitor local models:

```elixir
{:ok, models} = Lux.LLM.Ollama.ModelManager.list_models()
{:ok, _} = Lux.LLM.Ollama.ModelManager.ensure_model("llama3.2")
{:ok, info} = Lux.LLM.Ollama.ModelManager.show_model("llama3.2")
metrics = Lux.LLM.Ollama.ModelManager.get_metrics("llama3.2")
```
