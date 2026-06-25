defmodule Lux.LLM.Provider do
  @moduledoc """
  Universal LLM Provider Interface
  
  This module defines a behaviour and implementation for managing multiple
  LLM providers with automatic model selection, fallback handling, and
  optimization features.
  """

  alias Lux.LLM.Provider.{Registry, Selector, Monitor}

  @doc """
  Initializes the LLM provider system with configuration
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, any()}
  def start_link(opts) do
    Registry.start_link(opts)
  end

  @doc """
  Sends a completion request to an LLM provider
  """
  @spec complete(String.t(), keyword()) :: {:ok, String.t()} | {:error, any()}
  def complete(prompt, opts \\ []) do
    with {:ok, provider} <- Selector.select_provider(opts),
         {:ok, response} <- provider.complete(prompt, opts) do
      Monitor.record_success(provider.name(), response)
      {:ok, response}
    else
      {:error, reason} ->
        Monitor.record_failure(reason)
        {:error, reason}
    end
  end

  @doc """
  Embeds text using an LLM provider
  """
  @spec embed(String.t(), keyword()) :: {:ok, list()} | {:error, any()}
  def embed(text, opts \\ []) do
    with {:ok, provider} <- Selector.select_provider(opts),
         {:ok, embedding} <- provider.embed(text, opts) do
      Monitor.record_embedding(provider.name(), embedding)
      {:ok, embedding}
    else
      {:error, reason} ->
        Monitor.record_failure(reason)
        {:error, reason}
    end
  end

  @doc """
  Gets provider statistics and performance metrics
  """
  @spec stats() :: map()
  def stats do
    Monitor.get_stats()
  end

  @doc """
  Registers a new provider
  """
  @spec register_provider(atom(), module(), map()) :: :ok | {:error, any()}
  def register_provider(name, module, config) do
    Registry.register(name, module, config)
  end

  @doc """
  Removes a provider from the registry
  """
  @spec unregister_provider(atom()) :: :ok
  def unregister_provider(name) do
    Registry.unregister(name)
  end
end