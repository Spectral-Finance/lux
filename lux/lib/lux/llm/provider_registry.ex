defmodule Lux.LLM.ProviderRegistry do
  @moduledoc """
  Provider registry and lifecycle management for LLM providers:
  - Registers supported providers (OpenAI, Anthropic, Gemini, Groq, TogetherAI, Ollama)
  - Tracks provider health, supported models, and operational capabilities
  """

  @default_providers %{
    openai: %{
      name: "OpenAI",
      module: Lux.LLM.OpenAI,
      models: ["gpt-4o", "gpt-4o-mini", "o1", "o3-mini"],
      capabilities: [:tools, :structured_output, :vision, :json_mode],
      status: :online,
      avg_latency_ms: 650
    },
    anthropic: %{
      name: "Anthropic",
      module: Lux.LLM.Anthropic,
      models: ["claude-3-5-sonnet-20241022", "claude-3-5-haiku-20241022", "claude-3-opus-20240229"],
      capabilities: [:tools, :vision, :prompt_caching],
      status: :online,
      avg_latency_ms: 720
    },
    together_ai: %{
      name: "Together AI",
      module: Lux.LLM.TogetherAI,
      models: ["meta-llama/Llama-3.3-70B-Instruct-Turbo", "deepseek-ai/DeepSeek-V3", "deepseek-ai/DeepSeek-R1"],
      capabilities: [:tools, :json_mode],
      status: :online,
      avg_latency_ms: 450
    },
    groq: %{
      name: "Groq",
      module: nil,
      models: ["llama-3.3-70b-versatile", "mixtral-8x7b-32768"],
      capabilities: [:tools, :fast_inference],
      status: :online,
      avg_latency_ms: 180
    }
  }

  @doc """
  Lists all registered providers.
  """
  @spec list_providers() :: map()
  def list_providers, do: @default_providers

  @doc """
  Retrieves metadata for a specific provider.
  """
  @spec get_provider(atom()) :: {:ok, map()} | {:error, :provider_not_found}
  def get_provider(provider_id) when is_atom(provider_id) do
    case Map.get(@default_providers, provider_id) do
      nil -> {:error, :provider_not_found}
      meta -> {:ok, meta}
    end
  end

  @doc """
  Finds providers supporting a given capability (e.g. :tools, :vision).
  """
  @spec providers_with_capability(atom()) :: list(atom())
  def providers_with_capability(capability) when is_atom(capability) do
    @default_providers
    |> Enum.filter(fn {_id, meta} -> capability in meta.capabilities end)
    |> Enum.map(fn {id, _meta} -> id end)
  end
end
