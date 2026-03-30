defmodule Lux.LLM.ProviderRegistry do
  @moduledoc """
  Registry for LLM providers.

  Manages provider registration, configuration, and lookup.
  All providers are stored in an ETS table for fast concurrent access.

  ## Provider Configuration

  Each provider has the following configuration:

    * `:module` - The provider module implementing `Lux.LLM` behaviour
    * `:models` - List of supported model names
    * `:priority` - Default priority for selection (lower = higher priority)
    * `:cost_per_1k_tokens` - Cost per 1000 tokens (input/output)
    * `:max_tokens` - Maximum context length
    * `:features` - Supported features (streaming, tools, etc.)
    * `:rate_limit` - Rate limiting configuration
    * `:enabled` - Whether the provider is enabled

  ## Usage

      # Register a provider
      ProviderRegistry.register(:openai, %{
        module: Lux.LLM.OpenAI,
        models: ["gpt-4", "gpt-3.5-turbo"],
        cost_per_1k_tokens: %{input: 0.03, output: 0.06},
        max_tokens: 8192,
        features: [:streaming, :tools, :json_mode],
        priority: 1
      })

      # Get provider config
      config = ProviderRegistry.get_config(:openai)

      # List all providers
      providers = ProviderRegistry.list_providers()

  """

  use Agent

  @table_name :lux_llm_provider_registry

  @type provider_name :: atom()
  @type provider_config :: map()

  @doc """
  Start the provider registry.
  """
  def start_link(_opts \\ []) do
    Agent.start_link(fn -> init_registry() end, name: __MODULE__)
  end

  @doc """
  Register a new provider.

  ## Examples

      iex> ProviderRegistry.register(:openai, %{module: Lux.LLM.OpenAI})
      :ok

  """
  @spec register(provider_name(), provider_config()) :: :ok | {:error, term()}
  def register(name, config) do
    with :ok <- validate_config(config) do
      Agent.update(__MODULE__, fn state ->
        :ets.insert(@table_name, {name, Map.put(config, :registered_at, DateTime.utc_now())})
        Map.put(state, name, config)
      end)
    end
  end

  @doc """
  Unregister a provider.

  ## Examples

      iex> ProviderRegistry.unregister(:deprecated_provider)
      :ok

  """
  @spec unregister(provider_name()) :: :ok
  def unregister(name) do
    Agent.update(__MODULE__, fn state ->
      :ets.delete(@table_name, name)
      Map.delete(state, name)
    end)
  end

  @doc """
  Get provider configuration.

  ## Examples

      iex> ProviderRegistry.get_config(:openai)
      %{module: Lux.LLM.OpenAI, ...}

  """
  @spec get_config(provider_name()) :: provider_config() | nil
  def get_config(name) do
    case :ets.lookup(@table_name, name) do
      [{^name, config}] -> config
      [] -> nil
    end
  end

  @doc """
  List all registered providers.

  ## Examples

      iex> ProviderRegistry.list_providers()
      [:openai, :anthropic, :together_ai]

  """
  @spec list_providers() :: [provider_name()]
  def list_providers do
    :ets.match(@table_name, {:"$1", :_})
    |> List.flatten()
  end

  @doc """
  List enabled providers only.

  ## Examples

      iex> ProviderRegistry.list_enabled()
      [:openai, :anthropic]

  """
  @spec list_enabled() :: [provider_name()]
  def list_enabled do
    :ets.tab2list(@table_name)
    |> Enum.filter(fn {_name, config} -> Map.get(config, :enabled, true) end)
    |> Enum.map(fn {name, _config} -> name end)
  end

  @doc """
  Check if a provider is registered.

  ## Examples

      iex> ProviderRegistry.registered?(:openai)
      true

  """
  @spec registered?(provider_name()) :: boolean()
  def registered?(name) do
    :ets.member(@table_name, name)
  end

  @doc """
  Enable a provider.

  ## Examples

      iex> ProviderRegistry.enable(:openai)
      :ok

  """
  @spec enable(provider_name()) :: :ok | {:error, :not_found}
  def enable(name) do
    case get_config(name) do
      nil -> {:error, :not_found}
      config ->
        Agent.update(__MODULE__, fn state ->
          updated_config = Map.put(config, :enabled, true)
          :ets.insert(@table_name, {name, updated_config})
          Map.put(state, name, updated_config)
        end)
    end
  end

  @doc """
  Disable a provider.

  ## Examples

      iex> ProviderRegistry.disable(:deprecated_provider)
      :ok

  """
  @spec disable(provider_name()) :: :ok | {:error, :not_found}
  def disable(name) do
    case get_config(name) do
      nil -> {:error, :not_found}
      config ->
        Agent.update(__MODULE__, fn state ->
          updated_config = Map.put(config, :enabled, false)
          :ets.insert(@table_name, {name, updated_config})
          Map.put(state, name, updated_config)
        end)
    end
  end

  @doc """
  Get models for a provider.

  ## Examples

      iex> ProviderRegistry.get_models(:openai)
      ["gpt-4", "gpt-3.5-turbo"]

  """
  @spec get_models(provider_name()) :: [String.t()] | []
  def get_models(name) do
    case get_config(name) do
      nil -> []
      config -> Map.get(config, :models, [])
    end
  end

  @doc """
  Update provider configuration.

  ## Examples

      iex> ProviderRegistry.update(:openai, %{priority: 2})
      :ok

  """
  @spec update(provider_name(), map()) :: :ok | {:error, :not_found}
  def update(name, updates) do
    case get_config(name) do
      nil -> {:error, :not_found}
      config ->
        Agent.update(__MODULE__, fn state ->
          updated_config = Map.merge(config, updates)
          :ets.insert(@table_name, {name, updated_config})
          Map.put(state, name, updated_config)
        end)
    end
  end

  # Private functions

  defp init_registry do
    if :ets.whereis(@table_name) == :undefined do
      :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
    end
    register_default_providers()
  end

  defp register_default_providers do
    # Register OpenAI
    :ets.insert(@table_name, {:openai, %{
      module: Lux.LLM.OpenAI,
      models: ["gpt-4", "gpt-4-turbo", "gpt-3.5-turbo"],
      cost_per_1k_tokens: %{
        "gpt-4" => %{input: 0.03, output: 0.06},
        "gpt-4-turbo" => %{input: 0.01, output: 0.03},
        "gpt-3.5-turbo" => %{input: 0.0005, output: 0.0015}
      },
      max_tokens: 128000,
      features: [:streaming, :tools, :json_mode, :vision],
      priority: 1,
      enabled: true,
      registered_at: DateTime.utc_now()
    }})

    # Register Anthropic
    :ets.insert(@table_name, {:anthropic, %{
      module: Lux.LLM.Anthropic,
      models: ["claude-3-opus-20240229", "claude-3-sonnet-20240229", "claude-3-haiku-20240307"],
      cost_per_1k_tokens: %{
        "claude-3-opus-20240229" => %{input: 0.015, output: 0.075},
        "claude-3-sonnet-20240229" => %{input: 0.003, output: 0.015},
        "claude-3-haiku-20240307" => %{input: 0.00025, output: 0.00125}
      },
      max_tokens: 200000,
      features: [:streaming, :tools, :vision],
      priority: 2,
      enabled: true,
      registered_at: DateTime.utc_now()
    }})

    # Register Together AI
    :ets.insert(@table_name, {:together_ai, %{
      module: Lux.LLM.TogetherAI,
      models: ["mistralai/Mixtral-8x7B-Instruct-v0.1", "meta-llama/Llama-3-70b-chat-hf"],
      cost_per_1k_tokens: %{
        "mistralai/Mixtral-8x7B-Instruct-v0.1" => %{input: 0.0006, output: 0.0006},
        "meta-llama/Llama-3-70b-chat-hf" => %{input: 0.0009, output: 0.0009}
      },
      max_tokens: 8192,
      features: [:streaming, :tools],
      priority: 3,
      enabled: true,
      registered_at: DateTime.utc_now()
    }})

    # Register Ollama (local models - zero cost!)
    :ets.insert(@table_name, {:ollama, %{
      module: Lux.LLM.Ollama,
      models: ["llama2", "mistral", "codellama", "llama3"],
      cost_per_1k_tokens: %{
        default: %{input: 0.0, output: 0.0}
      },
      max_tokens: 4096,
      features: [:streaming, :local, :no_cost],
      priority: 4,
      enabled: true,
      registered_at: DateTime.utc_now()
    }})

    # Register OpenRouter (unified API for hundreds of models)
    :ets.insert(@table_name, {:openrouter, %{
      module: Lux.LLM.OpenRouter,
      models: [
        "anthropic/claude-3.5-sonnet",
        "openai/gpt-4o",
        "openai/gpt-4o-mini",
        "google/gemini-pro",
        "meta-llama/llama-3-70b-instruct",
        "mistralai/mistral-7b-instruct"
      ],
      cost_per_1k_tokens: %{
        "anthropic/claude-3.5-sonnet" => %{input: 0.003, output: 0.015},
        "openai/gpt-4o" => %{input: 0.005, output: 0.015},
        "openai/gpt-4o-mini" => %{input: 0.00015, output: 0.0006},
        "google/gemini-pro" => %{input: 0.00125, output: 0.005},
        "meta-llama/llama-3-70b-instruct" => %{input: 0.0009, output: 0.0009},
        "mistralai/mistral-7b-instruct" => %{input: 0.0002, output: 0.0006}
      },
      max_tokens: 128_000,
      features: [:streaming, :tools, :json_mode],
      priority: 5,
      enabled: true,
      registered_at: DateTime.utc_now()
    }})

    %{}
  end

  defp validate_config(config) do
    required_keys = [:module]

    missing_keys = Enum.filter(required_keys, fn key -> not Map.has_key?(config, key) end)

    if Enum.empty?(missing_keys) do
      :ok
    else
      {:error, {:missing_keys, missing_keys}}
    end
  end
end
