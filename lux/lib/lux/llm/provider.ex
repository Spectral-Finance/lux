defmodule Lux.LLM.Provider do
  @moduledoc """
  Universal LLM Provider interface and registry.

  This module provides a unified interface for multiple LLM providers,
  with automatic model selection, fallback handling, and performance monitoring.

  ## Features

  - Universal provider interface
  - Automatic model selection based on task requirements
  - Smart fallback handling when providers fail
  - Cost tracking and optimization
  - Performance monitoring and analytics

  ## Usage

      # Call with automatic provider selection
      {:ok, response} = Lux.LLM.Provider.call("Hello, world!", [], %{})

      # Call with specific provider
      {:ok, response} = Lux.LLM.Provider.call("Hello!", [], %{
        provider: :openai,
        model: "gpt-4"
      })

      # Get available providers
      providers = Lux.LLM.Provider.list_providers()

      # Get provider stats
      stats = Lux.LLM.Provider.get_stats(:openai)
  """

  alias Lux.LLM.ProviderRegistry
  alias Lux.LLM.ModelSelector
  alias Lux.LLM.FallbackHandler
  alias Lux.LLM.CostTracker
  alias Lux.LLM.PerformanceMonitor

  @type provider_name :: atom()
  @type model_name :: String.t()
  @type config :: map()

  @doc """
  Call an LLM provider with automatic selection and fallback.

  ## Options

    * `:provider` - Specific provider to use (optional)
    * `:model` - Specific model to use (optional)
    * `:fallback` - List of fallback providers (default: all registered)
    * `:max_retries` - Maximum retry attempts (default: 3)
    * `:timeout` - Request timeout in ms (default: 60000)
    * `:cost_limit` - Maximum cost in USD (optional)
    * `:priority` - Selection priority: :cost | :speed | :quality (default: :balanced)

  ## Examples

      iex> Lux.LLM.Provider.call("Hello!", [], %{})
      {:ok, %Lux.LLM.Response{...}}

      iex> Lux.LLM.Provider.call("Hello!", [], %{provider: :openai})
      {:ok, %Lux.LLM.Response{...}}

  """
  @spec call(String.t(), list(), map()) :: {:ok, map()} | {:error, term()}
  def call(prompt, tools, opts \\ %{}) do
    with {:ok, config} <- validate_config(opts),
         {:ok, provider_chain} <- build_provider_chain(config),
         {:ok, response} <- execute_with_fallback(prompt, tools, provider_chain, config) do
      {:ok, response}
    end
  end

  @doc """
  Register a new LLM provider.

  ## Options

    * `:module` - Provider module (required)
    * `:models` - List of supported models (required)
    * `:priority` - Default priority (default: 100)
    * `:cost_per_1k_tokens` - Cost per 1000 tokens (optional)
    * `:max_tokens` - Maximum context length (optional)
    * `:features` - Supported features (optional)

  ## Examples

      iex> Lux.LLM.Provider.register(:openai, %{
      ...>   module: Lux.LLM.OpenAI,
      ...>   models: ["gpt-4", "gpt-3.5-turbo"],
      ...>   cost_per_1k_tokens: 0.03
      ...> })
      :ok

  """
  @spec register(provider_name(), map()) :: :ok | {:error, term()}
  def register(name, config) do
    ProviderRegistry.register(name, config)
  end

  @doc """
  Unregister an LLM provider.

  ## Examples

      iex> Lux.LLM.Provider.unregister(:deprecated_provider)
      :ok

  """
  @spec unregister(provider_name()) :: :ok
  def unregister(name) do
    ProviderRegistry.unregister(name)
  end

  @doc """
  List all registered providers.

  ## Examples

      iex> Lux.LLM.Provider.list_providers()
      [:openai, :anthropic, :together_ai]

  """
  @spec list_providers() :: [provider_name()]
  def list_providers do
    ProviderRegistry.list_providers()
  end

  @doc """
  Get provider configuration.

  ## Examples

      iex> Lux.LLM.Provider.get_config(:openai)
      %{module: Lux.LLM.OpenAI, models: ["gpt-4", ...], ...}

  """
  @spec get_config(provider_name()) :: map() | nil
  def get_config(name) do
    ProviderRegistry.get_config(name)
  end

  @doc """
  Get provider statistics.

  ## Examples

      iex> Lux.LLM.Provider.get_stats(:openai)
      %{requests: 100, tokens: 50000, cost: 1.5, avg_latency: 250}

  """
  @spec get_stats(provider_name()) :: map()
  def get_stats(name) do
    PerformanceMonitor.get_stats(name)
  end

  @doc """
  Get aggregate statistics for all providers.

  ## Examples

      iex> Lux.LLM.Provider.get_all_stats()
      %{total_requests: 500, total_cost: 10.5, ...}

  """
  @spec get_all_stats() :: map()
  def get_all_stats do
    PerformanceMonitor.get_all_stats()
  end

  @doc """
  Select the best provider for a given task.

  ## Options

    * `:priority` - :cost | :speed | :quality | :balanced
    * `:max_tokens` - Required token count
    * `:features` - Required features

  ## Examples

      iex> Lux.LLM.Provider.select_best(%{priority: :cost})
      {:openai, "gpt-3.5-turbo"}

  """
  @spec select_best(map()) :: {provider_name(), model_name()} | {:error, term()}
  def select_best(opts \\ %{}) do
    ModelSelector.select_best(opts)
  end

  @doc """
  Reset statistics for a provider.

  ## Examples

      iex> Lux.LLM.Provider.reset_stats(:openai)
      :ok

  """
  @spec reset_stats(provider_name()) :: :ok
  def reset_stats(name) do
    PerformanceMonitor.reset(name)
  end

  # Private functions

  defp validate_config(opts) do
    {:ok, Map.merge(default_config(), opts)}
  end

  defp default_config do
    %{
      fallback: :all,
      max_retries: 3,
      timeout: 60_000,
      priority: :balanced
    }
  end

  defp build_provider_chain(config) do
    case Map.get(config, :provider) do
      nil ->
        {:ok, ModelSelector.build_chain(config)}

      provider ->
        model = Map.get(config, :model)
        fallback = Map.get(config, :fallback, :all)

        chain = [{provider, model} | FallbackHandler.get_fallbacks(provider, fallback)]
        {:ok, chain}
    end
  end

  defp execute_with_fallback(prompt, tools, provider_chain, config) do
    FallbackHandler.execute(prompt, tools, provider_chain, config)
  end
end