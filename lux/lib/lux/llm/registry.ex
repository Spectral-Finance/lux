defmodule Lux.LLM.Registry do
  @moduledoc """
  Provider registry and discovery system for LLM providers in Lux.

  Maintains registered providers, their implementation modules, capabilities,
  and health states. Allows dynamic registration and querying of available LLMs.
  """

  @default_providers %{
    openai: %{
      id: :openai,
      name: "OpenAI",
      module: Lux.LLM.OpenAI,
      capabilities: [:tool_calling, :streaming, :vision, :json_mode],
      priority: 10,
      enabled: true,
      default_model: "gpt-4o",
      cost_tier: :standard
    },
    anthropic: %{
      id: :anthropic,
      name: "Anthropic",
      module: Lux.LLM.Anthropic,
      capabilities: [:tool_calling, :streaming, :vision, :long_context],
      priority: 15,
      enabled: true,
      default_model: "claude-3-5-sonnet-20241022",
      cost_tier: :premium
    },
    together_ai: %{
      id: :together_ai,
      name: "Together AI",
      module: Lux.LLM.TogetherAI,
      capabilities: [:tool_calling, :streaming, :open_source],
      priority: 25,
      enabled: true,
      default_model: "meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo",
      cost_tier: :economy
    },
    openrouter: %{
      id: :openrouter,
      name: "OpenRouter",
      module: Lux.LLM.OpenRouter,
      capabilities: [:tool_calling, :streaming, :universal_routing, :fallback],
      priority: 20,
      enabled: true,
      default_model: "anthropic/claude-3.5-sonnet",
      cost_tier: :variable
    },
    ollama: %{
      id: :ollama,
      name: "Ollama Local",
      module: Lux.LLM.Ollama,
      capabilities: [:local, :offline, :privacy, :streaming],
      priority: 30,
      enabled: true,
      default_model: "llama3.2:latest",
      cost_tier: :free
    },
    perplexity: %{
      id: :perplexity,
      name: "Perplexity AI",
      module: Lux.LLM.Perplexity,
      capabilities: [:web_search, :citations, :research, :streaming],
      priority: 22,
      enabled: true,
      default_model: "sonar-pro",
      cost_tier: :standard
    }
  }

  @doc """
  Lists all registered providers.
  """
  @spec list_providers() :: [map()]
  def list_providers do
    providers_map() |> Map.values()
  end

  @doc """
  Lists all enabled providers.
  """
  @spec list_enabled_providers() :: [map()]
  def list_enabled_providers do
    list_providers()
    |> Enum.filter(& &1.enabled)
    |> Enum.sort_by(& &1.priority)
  end

  @doc """
  Gets a provider by id or name.
  """
  @spec get_provider(atom() | String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_provider(id) when is_binary(id) do
    get_provider(String.to_existing_atom(id))
  rescue
    ArgumentError -> {:error, :not_found}
  end

  def get_provider(id) when is_atom(id) do
    case Map.get(providers_map(), id) do
      nil -> {:error, :not_found}
      provider -> {:ok, provider}
    end
  end

  @doc """
  Finds providers supporting specific capabilities.
  """
  @spec filter_by_capability(atom() | [atom()]) :: [map()]
  def filter_by_capability(required_caps) when is_list(required_caps) do
    list_enabled_providers()
    |> Enum.filter(fn provider ->
      Enum.all?(required_caps, fn cap -> cap in provider.capabilities end)
    end)
  end

  def filter_by_capability(single_cap) when is_atom(single_cap) do
    filter_by_capability([single_cap])
  end

  @doc """
  Registers or updates a provider dynamically.
  """
  @spec register_provider(map()) :: :ok
  def register_provider(%{id: id} = provider_info) do
    current = Process.get(:lux_llm_registered_providers, @default_providers)
    updated = Map.put(current, id, provider_info)
    Process.put(:lux_llm_registered_providers, updated)
    :ok
  end

  @doc """
  Disables a provider.
  """
  @spec disable_provider(atom()) :: :ok | {:error, :not_found}
  def disable_provider(id) do
    case get_provider(id) do
      {:ok, provider} ->
        register_provider(Map.put(provider, :enabled, false))

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Enables a provider.
  """
  @spec enable_provider(atom()) :: :ok | {:error, :not_found}
  def enable_provider(id) do
    case get_provider(id) do
      {:ok, provider} ->
        register_provider(Map.put(provider, :enabled, true))

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  defp providers_map do
    Process.get(:lux_llm_registered_providers, @default_providers)
  end
end
