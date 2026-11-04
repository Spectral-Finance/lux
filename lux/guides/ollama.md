# Local Model Support via Ollama in Lux

`Lux.LLM.Ollama` integrates local self-hosted LLMs via Ollama (`http://localhost:11434`) with model lifecycle management (`list_models/1`, `pull_model/2`, `delete_model/2`), hardware resource controls (`num_ctx`, `num_gpu`, `num_thread`, `keep_alive`), ETS caching, and throughput telemetry (`Spectral-Finance/lux#96`).

## Usage Examples

```elixir
alias Lux.LLM.Ollama

# 1. Manage local models
{:ok, models} = Ollama.list_models()
{:ok, _status} = Ollama.pull_model("llama3.2")

# 2. Run local inference with resource controls & caching
{:ok, signal} =
  Ollama.call("Summarize Soroban TVL growth", [], %{
    model: "llama3.2",
    num_ctx: 8192,
    num_gpu: 1,
    num_thread: 8,
    cache: true
  })
```
