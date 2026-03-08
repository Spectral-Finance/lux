# Ollama Integration

Lux supports [Ollama](https://ollama.ai) as a local LLM provider, enabling self-hosted model inference with full tool-calling support.

## Prerequisites

1. Install Ollama: https://ollama.ai/download
2. Pull a model:

```bash
ollama pull llama3.2
```

3. Ensure Ollama is running:

```bash
ollama serve
```

## Configuration

Add to your `config/config.exs`:

```elixir
# Set Ollama as the default LLM
config :lux, Lux.LLM, default_module: Lux.LLM.Ollama

# Configure Ollama endpoint (default: localhost:11434)
config :lux, Lux.LLM.Ollama,
  endpoint: "http://localhost:11434"

# Set default model
config :lux, :ollama_models,
  default: "llama3.2"
```

## Usage

### Basic Chat

```elixir
{:ok, response} = Lux.LLM.Ollama.call(
  "Explain quantum computing in simple terms",
  [],
  %{model: "llama3.2", json_response: false}
)
```

### With Tools

```elixir
{:ok, response} = Lux.LLM.Ollama.call(
  "What's the weather in Tokyo?",
  [MyApp.WeatherPrism],
  %{model: "llama3.2"}
)
```

### With Ollama-Specific Options

```elixir
{:ok, response} = Lux.LLM.Ollama.call(
  "Write a haiku",
  [],
  %{
    model: "llama3.2",
    temperature: 0.9,
    seed: 42,
    num_ctx: 4096,       # Context window size
    num_predict: 256,     # Max tokens to generate
    top_k: 40,            # Top-K sampling
    top_p: 0.9,           # Nucleus sampling
    repeat_penalty: 1.1,  # Repetition penalty
    keep_alive: "10m",    # Keep model loaded
    json_response: false
  }
)
```

## Model Management

### List Available Models

```elixir
{:ok, models} = Lux.LLM.Ollama.list_models()
# => [%{"name" => "llama3.2:latest", "size" => 2000000000, ...}, ...]
```

### Pull a New Model

```elixir
:ok = Lux.LLM.Ollama.pull_model("mistral")
:ok = Lux.LLM.Ollama.pull_model("codellama:13b")
```

### Show Model Details

```elixir
{:ok, details} = Lux.LLM.Ollama.show_model("llama3.2")
# => %{"modelfile" => "...", "parameters" => "...", "details" => %{...}}
```

### Delete a Model

```elixir
:ok = Lux.LLM.Ollama.delete_model("old-model")
```

### Health Check

```elixir
{:ok, %{"version" => "0.5.4"}} = Lux.LLM.Ollama.health_check()
```

## Remote Ollama Instances

To connect to a remote Ollama server:

```elixir
config :lux, Lux.LLM.Ollama,
  endpoint: "http://192.168.1.100:11434"
```

Or pass it per-call:

```elixir
Lux.LLM.Ollama.call("Hello!", [], %{
  endpoint: "http://my-gpu-server:11434",
  model: "llama3.2:70b"
})
```

## Supported Models

Ollama supports a wide range of models. Popular choices:

| Model | Parameters | Use Case |
|-------|-----------|----------|
| `llama3.2` | 3B | General purpose, fast |
| `llama3.2:70b` | 70B | High quality, slower |
| `mistral` | 7B | Balanced performance |
| `codellama` | 7B/13B/34B | Code generation |
| `phi3` | 3.8B | Compact, efficient |
| `gemma2` | 9B/27B | Google's open model |
| `qwen2.5` | 7B/72B | Multilingual |

Full list: https://ollama.ai/library

## Architecture Notes

The Ollama provider uses Ollama's OpenAI-compatible `/v1/chat/completions` endpoint, which means:

- Tool calling works the same as OpenAI
- Response format is identical to OpenAI
- All existing Prisms, Beams, and Lenses work seamlessly
- Switching between OpenAI and Ollama requires only a config change
