defmodule Lux.LLM.ProviderRegistry do
  @moduledoc """
  A registry for managing LLM providers with automatic model selection,
  fallback handling, and cost/performance monitoring.

  ## Features

  - Register and manage multiple LLM providers
  - Automatic model selection based on capabilities and preferences
  - Smart fallback handling when providers fail
  - Cost tracking and optimization
  - Performance monitoring and analytics
  - Provider health checking

  ## Usage

      # Start the registry (typically in your application supervision tree)
      Lux.LLM.ProviderRegistry.start_link([])

      # Register providers
      Lux.LLM.ProviderRegistry.register_provider(:openai, %{
        module: Lux.LLM.OpenAI,
        priority: 1,
        models: ["gpt-4", "gpt-3.5-turbo"],
        config: %{api_key: "sk-..."}
      })

      # Make a call with automatic provider selection
      Lux.LLM.ProviderRegistry.call("Hello!", [], %{
        model: "gpt-4",
        fallback: true
      })

      # Get provider stats
      Lux.LLM.ProviderRegistry.get_stats(:openai)
  """

  use GenServer

  require Logger

  @type provider_name :: atom()
  @type provider_config :: %{
          module: module(),
          priority: non_neg_integer(),
          models: [String.t()],
          config: map(),
          enabled: boolean(),
          rate_limit: non_neg_integer() | nil,
          tags: [atom()]
        }

  @type provider_stats :: %{
          total_calls: non_neg_integer(),
          successful_calls: non_neg_integer(),
          failed_calls: non_neg_integer(),
          total_tokens: non_neg_integer(),
          total_cost: float(),
          avg_latency_ms: float(),
          last_error: String.t() | nil,
          last_call_at: DateTime.t() | nil
        }

  @type state :: %{
          providers: %{provider_name() => provider_config()},
          stats: %{provider_name() => provider_stats()},
          model_routing: %{String.t() => provider_name()},
          fallback_chains: %{provider_name() => [provider_name()]}
        }

  # Known model-to-provider mappings for auto-detection
  @model_prefixes %{
    "gpt-" => :openai,
    "o1-" => :openai,
    "o3-" => :openai,
    "claude-" => :anthropic,
    "llama" => :ollama,
    "mistral" => :together_ai,
    "mixtral" => :together_ai,
    "gemma" => :ollama
  }

  # ─── Public API ───────────────────────────────────────────────────────────

  @doc """
  Starts the ProviderRegistry GenServer.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Registers a new LLM provider.

  ## Options

  - `:module` - The provider module implementing `Lux.LLM` behaviour (required)
  - `:priority` - Provider priority for fallback ordering (lower = higher priority, default: 10)
  - `:models` - List of supported model names (default: [])
  - `:config` - Default configuration for this provider (default: %{})
  - `:enabled` - Whether the provider is enabled (default: true)
  - `:rate_limit` - Max calls per minute (default: nil = unlimited)
  - `:tags` - Tags for categorization, e.g. [:fast, :cheap, :reasoning] (default: [])

  ## Examples

      iex> ProviderRegistry.register_provider(:openai, %{
      ...>   module: Lux.LLM.OpenAI,
      ...>   priority: 1,
      ...>   models: ["gpt-4", "gpt-4-turbo", "gpt-3.5-turbo"],
      ...>   config: %{api_key: "sk-..."},
      ...>   tags: [:reasoning, :tools]
      ...> })
      :ok
  """
  @spec register_provider(provider_name(), map()) :: :ok | {:error, term()}
  def register_provider(name, config, server \\ __MODULE__) do
    GenServer.call(server, {:register_provider, name, config})
  end

  @doc """
  Unregisters a provider.
  """
  @spec unregister_provider(provider_name()) :: :ok
  def unregister_provider(name, server \\ __MODULE__) do
    GenServer.call(server, {:unregister_provider, name})
  end

  @doc """
  Updates an existing provider's configuration.
  """
  @spec update_provider(provider_name(), map()) :: :ok | {:error, :not_found}
  def update_provider(name, updates, server \\ __MODULE__) do
    GenServer.call(server, {:update_provider, name, updates})
  end

  @doc """
  Enables or disables a provider.
  """
  @spec set_provider_enabled(provider_name(), boolean()) :: :ok | {:error, :not_found}
  def set_provider_enabled(name, enabled, server \\ __MODULE__) do
    GenServer.call(server, {:set_provider_enabled, name, enabled})
  end

  @doc """
  Lists all registered providers with their current status.
  """
  @spec list_providers() :: [%{name: provider_name(), config: provider_config(), stats: provider_stats()}]
  def list_providers(server \\ __MODULE__) do
    GenServer.call(server, :list_providers)
  end

  @doc """
  Gets statistics for a specific provider.
  """
  @spec get_stats(provider_name()) :: {:ok, provider_stats()} | {:error, :not_found}
  def get_stats(name, server \\ __MODULE__) do
    GenServer.call(server, {:get_stats, name})
  end

  @doc """
  Resets statistics for a provider or all providers.
  """
  @spec reset_stats(provider_name() | :all) :: :ok
  def reset_stats(target \\ :all, server \\ __MODULE__) do
    GenServer.call(server, {:reset_stats, target})
  end

  @doc """
  Makes an LLM call with automatic provider selection and fallback.

  This is the main entry point for making LLM calls through the registry.
  It will:
  1. Select the appropriate provider based on the model or tags
  2. Make the call
  3. If the call fails and fallback is enabled, try the next provider
  4. Track metrics for the call

  ## Options

  All standard provider options plus:
  - `:provider` - Force a specific provider (bypasses auto-selection)
  - `:fallback` - Enable fallback to other providers on failure (default: true)
  - `:max_retries` - Maximum number of fallback attempts (default: 3)
  - `:tags` - Select provider by tags (e.g., [:fast, :cheap])
  - `:timeout` - Call timeout in ms (default: 60_000)

  ## Examples

      # Auto-select provider based on model
      ProviderRegistry.call("Hello!", [], %{model: "gpt-4"})

      # Force a specific provider
      ProviderRegistry.call("Hello!", [], %{provider: :anthropic, model: "claude-3-opus"})

      # Select by tags
      ProviderRegistry.call("Hello!", [], %{tags: [:fast, :cheap]})
  """
  @spec call(Lux.LLM.prompt(), Lux.LLM.tools(), map()) ::
          {:ok, term()} | {:error, term()}
  def call(prompt, tools, options, server \\ __MODULE__) do
    GenServer.call(server, {:call, prompt, tools, options}, options[:timeout] || 120_000)
  end

  @doc """
  Configures a fallback chain for a provider.

  When the primary provider fails, the system will try each fallback in order.

  ## Examples

      ProviderRegistry.set_fallback_chain(:openai, [:anthropic, :together_ai])
  """
  @spec set_fallback_chain(provider_name(), [provider_name()]) :: :ok
  def set_fallback_chain(primary, fallbacks, server \\ __MODULE__) do
    GenServer.call(server, {:set_fallback_chain, primary, fallbacks})
  end

  @doc """
  Registers a model-to-provider routing rule.

  ## Examples

      ProviderRegistry.route_model("gpt-4", :openai)
      ProviderRegistry.route_model("claude-3-opus", :anthropic)
  """
  @spec route_model(String.t(), provider_name()) :: :ok
  def route_model(model, provider, server \\ __MODULE__) do
    GenServer.call(server, {:route_model, model, provider})
  end

  # ─── GenServer Callbacks ──────────────────────────────────────────────────

  @impl true
  def init(opts) do
    state = %{
      providers: %{},
      stats: %{},
      model_routing: %{},
      fallback_chains: %{}
    }

    # Auto-register providers from application config
    state = maybe_auto_register(state, opts)

    {:ok, state}
  end

  @impl true
  def handle_call({:register_provider, name, config}, _from, state) do
    provider_config = build_provider_config(config)

    case validate_provider_config(provider_config) do
      :ok ->
        new_providers = Map.put(state.providers, name, provider_config)
        new_stats = Map.put_new(state.stats, name, empty_stats())

        # Auto-register model routes
        new_routing =
          Enum.reduce(provider_config.models, state.model_routing, fn model, acc ->
            Map.put_new(acc, model, name)
          end)

        {:reply, :ok,
         %{state | providers: new_providers, stats: new_stats, model_routing: new_routing}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:unregister_provider, name}, _from, state) do
    new_providers = Map.delete(state.providers, name)
    new_routing = state.model_routing |> Enum.reject(fn {_k, v} -> v == name end) |> Map.new()
    new_chains = Map.delete(state.fallback_chains, name)

    {:reply, :ok,
     %{state | providers: new_providers, model_routing: new_routing, fallback_chains: new_chains}}
  end

  @impl true
  def handle_call({:update_provider, name, updates}, _from, state) do
    case Map.get(state.providers, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      existing ->
        updated = Map.merge(existing, updates)
        {:reply, :ok, %{state | providers: Map.put(state.providers, name, updated)}}
    end
  end

  @impl true
  def handle_call({:set_provider_enabled, name, enabled}, _from, state) do
    case Map.get(state.providers, name) do
      nil ->
        {:reply, {:error, :not_found}, state}

      existing ->
        updated = %{existing | enabled: enabled}
        {:reply, :ok, %{state | providers: Map.put(state.providers, name, updated)}}
    end
  end

  @impl true
  def handle_call(:list_providers, _from, state) do
    providers =
      Enum.map(state.providers, fn {name, config} ->
        %{
          name: name,
          config: config,
          stats: Map.get(state.stats, name, empty_stats())
        }
      end)

    {:reply, providers, state}
  end

  @impl true
  def handle_call({:get_stats, name}, _from, state) do
    case Map.get(state.stats, name) do
      nil -> {:reply, {:error, :not_found}, state}
      stats -> {:reply, {:ok, stats}, state}
    end
  end

  @impl true
  def handle_call({:reset_stats, :all}, _from, state) do
    new_stats = Map.new(state.stats, fn {name, _} -> {name, empty_stats()} end)
    {:reply, :ok, %{state | stats: new_stats}}
  end

  @impl true
  def handle_call({:reset_stats, name}, _from, state) do
    new_stats = Map.put(state.stats, name, empty_stats())
    {:reply, :ok, %{state | stats: new_stats}}
  end

  @impl true
  def handle_call({:call, prompt, tools, options}, _from, state) do
    provider_name = options[:provider] || resolve_provider(options, state)
    fallback_enabled = Map.get(options, :fallback, true)
    max_retries = Map.get(options, :max_retries, 3)

    providers_to_try = build_provider_chain(provider_name, fallback_enabled, max_retries, state)

    {result, new_state} = try_providers(providers_to_try, prompt, tools, options, state)

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:set_fallback_chain, primary, fallbacks}, _from, state) do
    new_chains = Map.put(state.fallback_chains, primary, fallbacks)
    {:reply, :ok, %{state | fallback_chains: new_chains}}
  end

  @impl true
  def handle_call({:route_model, model, provider}, _from, state) do
    new_routing = Map.put(state.model_routing, model, provider)
    {:reply, :ok, %{state | model_routing: new_routing}}
  end

  # ─── Private Functions ────────────────────────────────────────────────────

  defp build_provider_config(config) do
    %{
      module: config[:module] || config.module,
      priority: Map.get(config, :priority, 10),
      models: Map.get(config, :models, []),
      config: Map.get(config, :config, %{}),
      enabled: Map.get(config, :enabled, true),
      rate_limit: Map.get(config, :rate_limit, nil),
      tags: Map.get(config, :tags, [])
    }
  end

  defp validate_provider_config(%{module: nil}), do: {:error, :missing_module}

  defp validate_provider_config(%{module: module}) do
    if Code.ensure_loaded?(module) do
      if function_exported?(module, :call, 3) do
        :ok
      else
        {:error, {:invalid_module, "#{inspect(module)} does not implement call/3"}}
      end
    else
      {:error, {:module_not_loaded, module}}
    end
  end

  defp empty_stats do
    %{
      total_calls: 0,
      successful_calls: 0,
      failed_calls: 0,
      total_tokens: 0,
      total_cost: 0.0,
      avg_latency_ms: 0.0,
      last_error: nil,
      last_call_at: nil
    }
  end

  defp resolve_provider(options, state) do
    cond do
      # 1. Check explicit model routing
      model = options[:model] ->
        resolve_by_model(model, state)

      # 2. Check tags
      tags = options[:tags] ->
        resolve_by_tags(tags, state)

      # 3. Use highest priority enabled provider
      true ->
        resolve_by_priority(state)
    end
  end

  defp resolve_by_model(model, state) do
    # First check explicit routing table
    case Map.get(state.model_routing, model) do
      nil ->
        # Try prefix-based auto-detection
        case detect_provider_by_model(model) do
          nil -> resolve_by_priority(state)
          provider -> provider
        end

      provider ->
        provider
    end
  end

  defp detect_provider_by_model(model) do
    Enum.find_value(@model_prefixes, fn {prefix, provider} ->
      if String.starts_with?(model, prefix), do: provider
    end)
  end

  defp resolve_by_tags(tags, state) do
    state.providers
    |> Enum.filter(fn {_name, config} ->
      config.enabled && Enum.all?(tags, &(&1 in config.tags))
    end)
    |> Enum.sort_by(fn {_name, config} -> config.priority end)
    |> case do
      [{name, _} | _] -> name
      [] -> resolve_by_priority(state)
    end
  end

  defp resolve_by_priority(state) do
    state.providers
    |> Enum.filter(fn {_name, config} -> config.enabled end)
    |> Enum.sort_by(fn {_name, config} -> config.priority end)
    |> case do
      [{name, _} | _] -> name
      [] -> nil
    end
  end

  defp build_provider_chain(primary, false, _max, _state), do: [primary]

  defp build_provider_chain(primary, true, max, state) do
    # Use explicit fallback chain if configured, otherwise use priority ordering
    fallbacks =
      case Map.get(state.fallback_chains, primary) do
        nil ->
          state.providers
          |> Enum.filter(fn {name, config} -> name != primary && config.enabled end)
          |> Enum.sort_by(fn {_name, config} -> config.priority end)
          |> Enum.map(fn {name, _} -> name end)

        chain ->
          chain
      end

    [primary | fallbacks]
    |> Enum.take(max + 1)
    |> Enum.filter(&(&1 != nil))
  end

  defp try_providers([], _prompt, _tools, _options, state) do
    {{:error, :no_providers_available}, state}
  end

  defp try_providers([provider_name | rest], prompt, tools, options, state) do
    case Map.get(state.providers, provider_name) do
      nil ->
        Logger.warning("Provider #{provider_name} not found, trying next")
        try_providers(rest, prompt, tools, options, state)

      %{enabled: false} ->
        Logger.debug("Provider #{provider_name} is disabled, trying next")
        try_providers(rest, prompt, tools, options, state)

      provider_config ->
        # Merge provider default config with call options
        merged_config = Map.merge(provider_config.config, Map.drop(options, [:provider, :fallback, :max_retries, :tags, :timeout]))

        start_time = System.monotonic_time(:millisecond)

        case provider_config.module.call(prompt, tools, merged_config) do
          {:ok, result} = success ->
            latency = System.monotonic_time(:millisecond) - start_time
            tokens = extract_tokens(result)
            new_state = update_stats(state, provider_name, :success, latency, tokens)
            {success, new_state}

          {:error, reason} = _error ->
            latency = System.monotonic_time(:millisecond) - start_time
            new_state = update_stats(state, provider_name, {:error, reason}, latency, 0)

            if rest != [] do
              Logger.warning(
                "Provider #{provider_name} failed: #{inspect(reason)}, trying fallback"
              )

              try_providers(rest, prompt, tools, options, new_state)
            else
              {{:error, reason}, new_state}
            end
        end
    end
  end

  defp extract_tokens(%{metadata: %{usage: %{"total_tokens" => tokens}}}), do: tokens
  defp extract_tokens(%Lux.Signal{metadata: %{usage: %{"total_tokens" => tokens}}}), do: tokens
  defp extract_tokens(_), do: 0

  defp update_stats(state, provider_name, result, latency_ms, tokens) do
    stats = Map.get(state.stats, provider_name, empty_stats())

    updated =
      case result do
        :success ->
          total_calls = stats.total_calls + 1
          successful = stats.successful_calls + 1

          # Running average for latency
          avg_latency =
            if stats.total_calls == 0 do
              latency_ms * 1.0
            else
              (stats.avg_latency_ms * stats.total_calls + latency_ms) / total_calls
            end

          %{
            stats
            | total_calls: total_calls,
              successful_calls: successful,
              total_tokens: stats.total_tokens + tokens,
              avg_latency_ms: avg_latency,
              last_call_at: DateTime.utc_now()
          }

        {:error, reason} ->
          %{
            stats
            | total_calls: stats.total_calls + 1,
              failed_calls: stats.failed_calls + 1,
              last_error: inspect(reason),
              last_call_at: DateTime.utc_now()
          }
      end

    %{state | stats: Map.put(state.stats, provider_name, updated)}
  end

  defp maybe_auto_register(state, _opts) do
    # Auto-register from application config if available
    providers = Application.get_env(:lux, :llm_providers, [])

    Enum.reduce(providers, state, fn {name, config}, acc ->
      provider_config = build_provider_config(config)

      new_providers = Map.put(acc.providers, name, provider_config)
      new_stats = Map.put_new(acc.stats, name, empty_stats())

      new_routing =
        Enum.reduce(provider_config.models, acc.model_routing, fn model, routing ->
          Map.put_new(routing, model, name)
        end)

      %{acc | providers: new_providers, stats: new_stats, model_routing: new_routing}
    end)
  end
end
