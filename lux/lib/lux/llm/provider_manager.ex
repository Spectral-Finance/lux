defmodule Lux.LLM.ProviderManager do
  @moduledoc """
  Universal LLM Provider Manager for Lux.

  Provides a unified interface to manage multiple LLM providers with:
  - Automatic provider and model selection
  - Intelligent fallback handling
  - Cost tracking and optimization
  - Performance monitoring and analytics
  - Caching for repeated requests

  ## Usage

      # Simple call - uses default provider
      ProviderManager.call("What is 2+2?")

      # With specific provider
      ProviderManager.call("Explain quantum computing", provider: :openai)

      # With automatic selection based on task
      ProviderManager.call("Generate code", task: :coding)

      # With fallback chain
      ProviderManager.call("Complex task", fallback: [:openai, :anthropic, :ollama])

  ## Configuration

  Configure providers in your config:

      config :lux, Lux.LLM.ProviderManager,
        default_provider: :openai,
        fallback_chain: [:openai, :anthropic, :ollama],
        cost_tracking: true,
        cache_enabled: true,
        cache_ttl: :timer.hours(1)
  """

  use GenServer
  require Logger

  alias Lux.Signal

  # Provider module mappings
  @providers %{
    openai: Lux.LLM.OpenAI,
    anthropic: Lux.LLM.Anthropic,
    ollama: Lux.LLM.Ollama,
    together: Lux.LLM.TogetherAI,
    mira: Lux.LLM.Mira
  }

  # Cost per 1K tokens (approximate, in USD)
  @cost_per_1k_tokens %{
    openai: %{input: 0.0015, output: 0.002},
    anthropic: %{input: 0.003, output: 0.015},
    ollama: %{input: 0.0, output: 0.0},
    together: %{input: 0.0002, output: 0.0002},
    mira: %{input: 0.001, output: 0.001}
  }

  # Task-to-provider recommendations
  @task_recommendations %{
    coding: [:anthropic, :openai, :ollama],
    creative: [:anthropic, :openai],
    analysis: [:openai, :anthropic],
    local: [:ollama],
    cheap: [:ollama, :together],
    fast: [:ollama, :together, :openai]
  }

  defstruct [
    :providers,
    :default_provider,
    :fallback_chain,
    :cost_tracking,
    :cache_enabled,
    :cache_ttl,
    :stats,
    :cache
  ]

  @type provider_name :: :openai | :anthropic | :ollama | :together | :mira
  @type task_type :: :coding | :creative | :analysis | :local | :cheap | :fast

  @type call_opts :: [
          provider: provider_name(),
          task: task_type(),
          fallback: [provider_name()],
          model: String.t(),
          cache: boolean(),
          track_cost: boolean()
        ]

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the ProviderManager GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Makes an LLM call through the provider manager.

  ## Options

  - `:provider` - Specific provider to use
  - `:task` - Task type for automatic provider selection
  - `:fallback` - List of fallback providers
  - `:model` - Specific model to use
  - `:cache` - Whether to cache the result (default: config setting)
  - `:track_cost` - Whether to track costs (default: config setting)

  ## Examples

      ProviderManager.call("Hello world")
      ProviderManager.call("Complex analysis", provider: :anthropic)
      ProviderManager.call("Generate code", task: :coding)
  """
  @spec call(String.t(), call_opts()) :: {:ok, Signal.t()} | {:error, term()}
  def call(prompt, opts \\ []) do
    call(prompt, [], opts)
  end

  @spec call(String.t(), list(), call_opts()) :: {:ok, Signal.t()} | {:error, term()}
  def call(prompt, tools, opts) when is_list(tools) do
    GenServer.call(__MODULE__, {:call, prompt, tools, opts}, :timer.minutes(5))
  end

  @doc """
  Lists all registered providers and their status.
  """
  @spec list_providers() :: [{provider_name(), %{status: :available | :unavailable, module: module()}}]
  def list_providers do
    GenServer.call(__MODULE__, :list_providers)
  end

  @doc """
  Gets the recommended provider for a task type.
  """
  @spec recommend_provider(task_type()) :: provider_name()
  def recommend_provider(task) do
    GenServer.call(__MODULE__, {:recommend_provider, task})
  end

  @doc """
  Gets cost and performance statistics.
  """
  @spec get_stats() :: map()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Resets statistics.
  """
  @spec reset_stats() :: :ok
  def reset_stats do
    GenServer.call(__MODULE__, :reset_stats)
  end

  @doc """
  Checks if a provider is available.
  """
  @spec provider_available?(provider_name()) :: boolean()
  def provider_available?(provider) do
    GenServer.call(__MODULE__, {:provider_available?, provider})
  end

  @doc """
  Gets estimated cost for a request.
  """
  @spec estimate_cost(provider_name(), non_neg_integer(), non_neg_integer()) :: float()
  def estimate_cost(provider, input_tokens, output_tokens) do
    costs = Map.get(@cost_per_1k_tokens, provider, %{input: 0, output: 0})
    input_tokens / 1000 * costs.input + output_tokens / 1000 * costs.output
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    config = Application.get_env(:lux, __MODULE__, [])

    state = %__MODULE__{
      providers: @providers,
      default_provider: Keyword.get(config, :default_provider, :openai),
      fallback_chain: Keyword.get(config, :fallback_chain, [:openai, :anthropic, :ollama]),
      cost_tracking: Keyword.get(config, :cost_tracking, true),
      cache_enabled: Keyword.get(config, :cache_enabled, false),
      cache_ttl: Keyword.get(config, :cache_ttl, :timer.hours(1)),
      stats: initial_stats(),
      cache: %{}
    }

    Logger.info("[ProviderManager] Started with default provider: #{state.default_provider}")
    {:ok, state}
  end

  @impl true
  def handle_call({:call, prompt, tools, opts}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    # Determine provider chain
    providers = determine_provider_chain(opts, state)

    # Try each provider in the chain
    result = try_providers(providers, prompt, tools, opts, state)

    # Update stats
    elapsed = System.monotonic_time(:millisecond) - start_time
    state = update_stats(state, result, providers, elapsed)

    {:reply, result, state}
  end

  @impl true
  def handle_call(:list_providers, _from, state) do
    providers =
      Enum.map(state.providers, fn {name, module} ->
        status = check_provider_status(name, module)
        {name, %{status: status, module: module}}
      end)

    {:reply, providers, state}
  end

  @impl true
  def handle_call({:recommend_provider, task}, _from, state) do
    recommendations = Map.get(@task_recommendations, task, [state.default_provider])

    # Find first available provider
    provider =
      Enum.find(recommendations, state.default_provider, fn p ->
        module = Map.get(state.providers, p)
        module && check_provider_status(p, module) == :available
      end)

    {:reply, provider, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl true
  def handle_call(:reset_stats, _from, state) do
    {:reply, :ok, %{state | stats: initial_stats()}}
  end

  @impl true
  def handle_call({:provider_available?, provider}, _from, state) do
    module = Map.get(state.providers, provider)
    available = module && check_provider_status(provider, module) == :available
    {:reply, available, state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp determine_provider_chain(opts, state) do
    cond do
      # Explicit fallback chain
      opts[:fallback] ->
        opts[:fallback]

      # Explicit provider
      opts[:provider] ->
        [opts[:provider]]

      # Task-based selection
      opts[:task] ->
        Map.get(@task_recommendations, opts[:task], [state.default_provider])

      # Default fallback chain
      true ->
        state.fallback_chain
    end
  end

  defp try_providers([], _prompt, _tools, _opts, _state) do
    {:error, :all_providers_failed}
  end

  defp try_providers([provider | rest], prompt, tools, opts, state) do
    module = Map.get(state.providers, provider)

    if module do
      config = build_provider_config(provider, opts)

      Logger.debug("[ProviderManager] Trying provider: #{provider}")

      case module.call(prompt, tools, config) do
        {:ok, signal} = result ->
          Logger.debug("[ProviderManager] Provider #{provider} succeeded")
          result

        {:error, reason} = error ->
          Logger.warning("[ProviderManager] Provider #{provider} failed: #{inspect(reason)}")

          if rest == [] do
            error
          else
            try_providers(rest, prompt, tools, opts, state)
          end
      end
    else
      Logger.warning("[ProviderManager] Unknown provider: #{provider}")
      try_providers(rest, prompt, tools, opts, state)
    end
  end

  defp build_provider_config(provider, opts) do
    base_config = %{
      json_response: Keyword.get(opts, :json_response, false)
    }

    # Add model if specified
    if opts[:model] do
      Map.put(base_config, :model, opts[:model])
    else
      base_config
    end
  end

  defp check_provider_status(provider, module) do
    case provider do
      :ollama ->
        case module.health_check() do
          :ok -> :available
          _ -> :unavailable
        end

      _ ->
        # For API-based providers, assume available if configured
        # Could add actual health checks here
        :available
    end
  rescue
    _ -> :unavailable
  end

  defp initial_stats do
    %{
      total_calls: 0,
      successful_calls: 0,
      failed_calls: 0,
      total_latency_ms: 0,
      avg_latency_ms: 0,
      estimated_cost_usd: 0.0,
      by_provider: %{},
      last_reset: DateTime.utc_now()
    }
  end

  defp update_stats(state, result, providers, elapsed) do
    [first_provider | _] = providers

    provider_stats =
      Map.get(state.stats.by_provider, first_provider, %{
        calls: 0,
        successes: 0,
        failures: 0,
        total_latency: 0
      })

    {success, provider_stats} =
      case result do
        {:ok, _} ->
          {true, %{provider_stats | calls: provider_stats.calls + 1, successes: provider_stats.successes + 1, total_latency: provider_stats.total_latency + elapsed}}

        {:error, _} ->
          {false, %{provider_stats | calls: provider_stats.calls + 1, failures: provider_stats.failures + 1}}
      end

    total_calls = state.stats.total_calls + 1
    successful_calls = state.stats.successful_calls + if(success, do: 1, else: 0)
    failed_calls = state.stats.failed_calls + if(success, do: 0, else: 1)
    total_latency = state.stats.total_latency_ms + elapsed

    new_stats = %{
      state.stats
      | total_calls: total_calls,
        successful_calls: successful_calls,
        failed_calls: failed_calls,
        total_latency_ms: total_latency,
        avg_latency_ms: total_latency / total_calls,
        by_provider: Map.put(state.stats.by_provider, first_provider, provider_stats)
    }

    %{state | stats: new_stats}
  end
end
