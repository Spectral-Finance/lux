# Local Model Support via Ollama

## Overview
Adds a first-class `Lux.LLM.Ollama` provider implementing the shared `Lux.LLM.Provider` behaviour, letting Lux run fully local models (Llama 3.1, Mistral, Qwen, etc.) through an Ollama daemon with **no API key and no cloud dependency**. Supports chat, streaming, embeddings, model listing, and pull.

## `lib/lux/llm/ollama.ex`
```elixir
defmodule Lux.LLM.Ollama do
  @moduledoc """
  Local model provider backed by an Ollama daemon.

  Configure the daemon URL:

      config :lux, ollama_base_url: "http://localhost:11434"

  No API key required — `available?/0` probes the daemon.
  """

  @behaviour Lux.LLM.Provider

  @default_model "llama3.1"

  @impl true
  def name, do: :ollama

  @impl true
  def available? do
    case Lux.HTTP.get_json(base_url() <> "/api/tags", []) do
      {:ok, _} -> true
      _ -> false
    end
  end

  @impl true
  def chat(req) do
    body = %{
      model: req.model,
      messages: Enum.map(req.messages, &%{role: to_string(&1.role), content: &1.content}),
      stream: false,
      options: %{temperature: req.temperature, num_predict: req.max_tokens}
    }

    case Lux.HTTP.post_json(base_url() <> "/api/chat", body, json_headers()) do
      {:ok, %{"message" => %{"content" => content}, "model" => model} = raw} ->
        {:ok, %{
          content: content,
          tool_calls: [],
          usage: %{
            input_tokens: get_in(raw, ["prompt_eval_count"]) || 0,
            output_tokens: get_in(raw, ["eval_count"]) || 0
          },
          model: model,
          provider: :ollama,
          raw: raw
        }}

      {:error, r} -> {:error, r}
    end
  end

  @impl true
  def stream(req, fun) when is_function(fun, 1) do
    body = %{
      model: req.model,
      messages: Enum.map(req.messages, &%{role: to_string(&1.role), content: &1.content}),
      stream: true,
      options: %{temperature: req.temperature, num_predict: req.max_tokens}
    }

    Lux.HTTP.post_stream(base_url() <> "/api/chat", body, json_headers(), fn line ->
      case Jason.decode(line) do
        {:ok, %{"message" => %{"content" => c}} = chunk} when c != "" ->
          fun.(%{delta: c, done: chunk["done"] || false})
        _ -> :ok
      end
    end)
  end

  @impl true
  def embed(text, opts) do
    model = Keyword.get(opts, :model, "nomic-embed-text")
    case Lux.HTTP.post_json(base_url() <> "/api/embeddings", %{model: model, prompt: text}, json_headers()) do
      {:ok, %{"embedding" => e}} -> {:ok, e}
      {:error, r} -> {:error, r}
    end
  end

  @doc "List locally available models."
  def list_models do
    case Lux.HTTP.get_json(base_url() <> "/api/tags", []) do
      {:ok, %{"models" => models}} -> {:ok, Enum.map(models, & &1["name"])}
      {:error, r} -> {:error, r}
    end
  end

  @doc "Pull a model from the Ollama registry."
  def pull(model) do
    Lux.HTTP.post_json(base_url() <> "/api/pull", %{model: model, stream: false}, json_headers())
  end

  def default_model, do: @default_model

  defp base_url, do: Application.get_env(:lux, :ollama_base_url, "http://localhost:11434")
  defp json_headers, do: [{"content-type", "application/json"}]
end
```

## Register the provider in `lib/lux/llm.ex`
```elixir
@providers %{
  anthropic: Lux.LLM.Anthropic,
  openai: Lux.LLM.OpenAI,
  together_ai: Lux.LLM.TogetherAI,
  mira: Lux.LLM.Mira,
  ollama: Lux.LLM.Ollama,        # <-- local models
  openrouter: Lux.LLM.OpenRouter
}

@default_model %{
  # ...
  ollama: "llama3.1"
}
```

## `config/config.exs`
```elixir
config :lux, ollama_base_url: System.get_env("OLLAMA_BASE_URL", "http://localhost:11434")
```

## Usage
```elixir
# Local, offline, zero-cost inference
{:ok, resp} = Lux.LLM.chat(
  [%{role: :user, content: "Summarize this contract in one line."}],
  provider: :ollama,
  model: "llama3.1"
)

# Streaming
Lux.LLM.stream("Tell me a story", fn %{delta: d} -> IO.write(d) end, provider: :ollama)

# Discover local models
{:ok, models} = Lux.LLM.Ollama.list_models()
```

## README section
```markdown
### Local Models (Ollama)
Run Lux entirely offline with no API keys:

1. Install Ollama: https://ollama.com/download
2. `ollama pull llama3.1`
3. `config :lux, ollama_base_url: "http://localhost:11434"`
4. `Lux.LLM.chat("hi", provider: :ollama)`

Supported: chat, streaming, embeddings (`nomic-embed-text`), model listing, model pull.
```

## Design notes
- **Zero credentials**: `available?/0` probes `/api/tags`, so Ollama auto-activates only when a daemon is reachable.
- **Same normalized contract** as cloud providers — switching `provider: :ollama` requires no caller changes.
- **Usage mapping**: Ollama's `prompt_eval_count`/`eval_count` → `input_tokens`/`output_tokens`.
- **Streaming** parses newline-delimited JSON from `/api/chat` with `stream: true`.
- **Local embeddings** via `nomic-embed-text` keep the whole pipeline on-device.

## Tests
```elixir
defmodule Lux.LLM.OllamaTest do
  use ExUnit.Case, async: true

  test "unavailable when daemon is down" do
    Application.put_env(:lux, :ollama_base_url, "http://127.0.0.1:1")
    refute Lux.LLM.Ollama.available?()
  end

  test "default model is llama3.1" do
    assert Lux.LLM.Ollama.default_model() == "llama3.1"
  end
end
```
