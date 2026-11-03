# Local Model Support via Ollama

This guide covers running self-hosted local LLMs in Lux using [Ollama](https://ollama.com). Local model support allows zero-latency, private, zero-cost AI execution on your own workstations, cloud GPUs, or edge nodes.

---

## 1. Overview & Architecture

Ollama runs a local daemon (default: `http://localhost:11434`) serving quantized GGUF weights powered by llama.cpp. Lux interfaces with Ollama through a unified adapter supporting tool calling, hardware fine-tuning, and VRAM management.

```
+-----------------------------------------------------------------------+
|                              Lux Agent                                |
+-----------------------------------------------------------------------+
                                   |
                                   v
             +-------------------------------------------+
             | Lux.Beams.Llm.Ollama.LocalInferenceBeam   |
             +-------------------------------------------+
               /                 |                     \
              v                  v                      v
    +-------------------+ +-------------------+ +-------------------+
    | ModelManagePrism  | | ModelCachePrism   | | ChatPrism         |
    | (Check / Pull)    | | (Pre-warm VRAM)   | | (Local Inference) |
    +-------------------+ +-------------------+ +-------------------+
                                   |
                                   v
             +-------------------------------------------+
             | Lux.LLM.Ollama (Behaviour: Lux.LLM)       |
             | - Function Calling (Beams / Prisms)       |
             | - Hardware Controls (GPU layers, threads) |
             | - Memory Management (`keep_alive`)        |
             +-------------------------------------------+
                                   |
                                   v
             +-------------------------------------------+
             | Ollama Daemon (http://localhost:11434)    |
             |  /api/chat                                |
             |  /api/tags                                |
             |  /api/ps (Active VRAM)                    |
             |  /api/pull                                |
             +-------------------------------------------+
```

---

## 2. Configuration

### Environment Variables

Configure the endpoint URL if Ollama runs on a remote server or container:

```bash
export OLLAMA_ENDPOINT="http://localhost:11434"
```

### Application Config

In `config/config.exs`:

```elixir
config :lux, :ollama_models,
  default: "llama3.2",
  coder: "qwen2.5-coder:7b",
  fast: "llama3.2:1b"

config :lux, :ollama,
  endpoint: "http://localhost:11434"
```

In `config/runtime.exs`:

```elixir
config :lux, :ollama,
  endpoint: env!("OLLAMA_ENDPOINT", :string!, "http://localhost:11434")
```

---

## 3. Core Modules

### 3.1 `Lux.LLM.Ollama`

Implements the standard `Lux.LLM` behaviour.

```elixir
# Basic call
{:ok, signal} = Lux.LLM.Ollama.call("Summarize the smart contract event", [], %{
  model: "llama3.2",
  temperature: 0.3,
  num_ctx: 8192
})

IO.puts(signal.payload.content)

# Inspect hardware performance
metrics = signal.metadata.metrics
IO.puts("Tokens/sec: #{metrics.eval_tokens_per_sec}")
IO.puts("Total latency: #{metrics.total_duration_ms}ms")
```

#### Hardware Controls

You can control compute resources per invocation:

```elixir
{:ok, signal} = Lux.LLM.Ollama.call("Audit code", [], %{
  model: "qwen2.5-coder:7b",
  num_gpu: 33,        # Offload 33 layers to GPU
  num_thread: 8,      # Allocate 8 CPU threads
  num_ctx: 16_384,    # Expand context window
  keep_alive: "30m"   # Keep weights in VRAM for 30 minutes
})
```

#### Tool Calling with Beams & Prisms

Native tool calling works seamlessly with local models:

```elixir
tools = [
  MyApp.WalletBalancePrism,
  MyApp.ExecuteTransferBeam
]

{:ok, signal} = Lux.LLM.Ollama.call("Check balance for 0x1234...", tools, %{
  model: "llama3.2"
})
```

---

### 3.2 `Lux.LLM.Ollama.ModelManager`

Manage models stored on disk:

```elixir
alias Lux.LLM.Ollama.ModelManager

# List all downloaded models
{:ok, models} = ModelManager.list_models()

# Check if model exists
true = ModelManager.model_installed?("llama3.2")

# Pull new model
{:ok, _} = ModelManager.pull_model("deepseek-r1:7b")

# Inspect running models in memory
{:ok, running} = ModelManager.list_running_models()
```

---

### 3.3 `Lux.LLM.Ollama.ResourceMonitor`

Monitor VRAM allocation and compute efficiency:

```elixir
alias Lux.LLM.Ollama.ResourceMonitor

{:ok, vram} = ResourceMonitor.get_vram_usage()
IO.puts("Active models: #{vram.active_models_count}")
IO.puts("VRAM consumed: #{vram.total_vram_gb} GB")
```

---

## 4. Dedicated Prisms

### `Lux.Prisms.Llm.Ollama.ChatPrism`
Inference prism with parameter configuration:

```elixir
{:ok, result} = Lux.Prisms.Llm.Ollama.ChatPrism.handler(%{
  "prompt" => "Analyze liquidity distribution",
  "model" => "llama3.2",
  "num_ctx" => 4096
}, %{})
```

### `Lux.Prisms.Llm.Ollama.ModelManagePrism`
Action-based model lifecycle:

```elixir
# List
{:ok, res} = Lux.Prisms.Llm.Ollama.ModelManagePrism.handler(%{"action" => "list"}, %{})

# Check
{:ok, res} = Lux.Prisms.Llm.Ollama.ModelManagePrism.handler(%{
  "action" => "check",
  "model_name" => "llama3.2"
}, %{})
```

### `Lux.Prisms.Llm.Ollama.ModelCachePrism`
Pre-warm or unload model weights:

```elixir
# Pre-warm
{:ok, res} = Lux.Prisms.Llm.Ollama.ModelCachePrism.handler(%{
  "action" => "preload",
  "model_name" => "llama3.2",
  "keep_alive" => "1h"
}, %{})

# Unload immediately
{:ok, res} = Lux.Prisms.Llm.Ollama.ModelCachePrism.handler(%{
  "action" => "unload",
  "model_name" => "llama3.2"
}, %{})
```

### `Lux.Prisms.Llm.Ollama.BenchmarkPrism`
Evaluates raw tokens per second:

```elixir
{:ok, stats} = Lux.Prisms.Llm.Ollama.BenchmarkPrism.handler(%{
  "model" => "llama3.2",
  "num_predict" => 150
}, %{})

IO.puts("Generation speed: #{stats.eval_tokens_per_sec} tokens/sec")
```

---

## 5. End-to-End Local Inference Beam

The `Lux.Beams.Llm.Ollama.OllamaLocalInferenceBeam` automates the entire lifecycle:
1. Verifies model exists.
2. Pre-warms weights in VRAM to eliminate first-token delay.
3. Executes prompt and tools.
4. Records performance and VRAM telemetry.

```elixir
{:ok, result, log} = Lux.Beams.Llm.Ollama.OllamaLocalInferenceBeam.run(%{
  prompt: "Synthesize latest DEX trades",
  model: "llama3.2",
  temperature: 0.1
})

IO.puts("Response: #{result.content}")
```

---

## 6. Testing

All components include comprehensive ExUnit unit tests with HTTP stubbing:

```bash
mix test test/unit/lux/llm/ollama_test.exs
mix test test/unit/lux/prisms/llm/ollama_prisms_test.exs
mix test test/unit/lux/beams/llm/ollama_beam_test.exs
```
