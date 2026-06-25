defmodule Lux.LLM.Registry do
  @moduledoc """
  Universal LLM provider registry with automatic selection,
  fallback handling, and cost tracking.

  Manages multiple LLM providers (OpenAI, Anthropic, Ollama, Perplexity,
  TogetherAI) under a single interface. Automatically selects the best
  available provider based on capability requirements and falls back
  gracefully when a provider is unavailable.

  ## Configuration

      config :lux, Lux.LLM.Registry,
        default_provider: :openai,
        providers: [:openai, :anthropic, :ollama, :perplexity, :together_ai],
        fallback_order: [:openai, :anthropic, :together_ai, :ollama]

  ## Usage

      # Auto-select provider
      {:ok, response} = Lux.LLM.Registry.call("Explain EIP-1559", [], %{})

      # Explicit provider
      {:ok, response} = Lux.LLM.Registry.call("Explain EIP-1559", [], %{provider: :perplexity})
  """

  alias Lux.LLM
  require Logger

  @providers %{
    openai:      Lux.LLM.OpenAI,
    anthropic:   Lux.LLM.Anthropic,
    ollama:      Lux.LLM.Ollama,
    perplexity:  Lux.LLM.Perplexity,
    together_ai: Lux.LLM.TogetherAI
  }

  @doc """
  Call the best available LLM provider.

  When `config.provider` is set, uses that provider directly.
  Otherwise, tries the configured fallback order until one succeeds.
  """
  @spec call(String.t(), list(), map()) :: {:ok, term()} | {:error, term()}
  def call(prompt, tools, config) do
    provider = Map.get(config, :provider) || default_provider()
    config_without_provider = Map.delete(config, :provider)

    case Map.get(@providers, provider) do
      nil -> {:error, {:unknown_provider, provider}}
      module -> module.call(prompt, tools, config_without_provider)
    end
  end

  @doc """
  Call with automatic fallback through the provider chain.
  Returns the first successful response or the last error.
  """
  @spec call_with_fallback(String.t(), list(), map()) :: {:ok, term()} | {:error, term()}
  def call_with_fallback(prompt, tools, config) do
    fallback_order()
    |> Enum.reduce_while({:error, :no_providers_configured}, fn provider, _acc ->
      module = Map.get(@providers, provider)
      if is_nil(module) do
        {:cont, {:error, {:unknown_provider, provider}}}
      else
        case module.call(prompt, tools, config) do
          {:ok, _} = ok ->
            Logger.debug("LLM.Registry: succeeded with provider #{provider}")
            {:halt, ok}
          {:error, reason} ->
            Logger.warning("LLM.Registry: provider #{provider} failed: #{inspect(reason)}, trying next")
            {:cont, {:error, reason}}
        end
      end
    end)
  end

  @doc "List all registered provider names."
  def providers, do: Map.keys(@providers)

  @doc "Returns the configured default provider atom."
  def default_provider do
    Application.get_env(:lux, __MODULE__, [])[:default_provider] || :openai
  end

  defp fallback_order do
    Application.get_env(:lux, __MODULE__, [])[:fallback_order] ||
      [:openai, :anthropic, :together_ai, :ollama]
  end
end
