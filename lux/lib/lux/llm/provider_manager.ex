defmodule Lux.LLM.ProviderManager do
  @moduledoc """
  Universal LLM Provider Manager for Lux.

  Provides a unified interface to manage multiple LLM providers with:
  - Automatic provider and model selection based on task type
  - Intelligent fallback handling with circuit breakers
  - Real-time cost tracking from API responses
  - Performance monitoring with latency percentiles
  - LRU caching with TTL for repeated requests
  - Rate limiting per provider
  - Health checks with configurable intervals

  ## Architecture

  The ProviderManager runs as a GenServer that maintains:
  - Provider registry with health status
  - Circuit breaker state per provider
  - LRU cache with configurable size and TTL
  - Real-time statistics and cost tracking
  - Rate limiter tokens per provider

  ## Usage

      # Start in your supervision tree
      children = [
        Lux.LLM.ProviderManager
      ]

      # Simple call - uses default provider
      ProviderManager.call("What is 2+2?")

      # With specific provider
      ProviderManager.call("Explain quantum computing", provider: :openai)

      # With automatic selection based on task
      ProviderManager.call("Generate code", task: :coding)

      # With fallback chain
      ProviderManager.call("Complex task", fallback: [:openai, :anthropic, :ollama])

      # With caching enabled
      ProviderManager.call("Repeated query", cache: true)

  ## Configuration

      config :lux, Lux.LLM.ProviderManager,
        default_provider: :openai,
        fallback_chain: [:openai, :anthropic, :ollama],
        cost_tracking: true,
        cache_enabled: true,
        cache_ttl: :timer.hours(1),
        cache_max_size: 1000,
        health_check_interval: :timer.minutes(5),
        circuit_breaker_threshold: 5,
        circuit_breaker_timeout: :timer.minutes(1),
        rate_limit_per_minute: %{
          openai: 60,
          anthropic: 60,
          ollama: 1000,
          together: 60,
          mira: 60
        }
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

  # Cost per 1K tokens (approximate, in USD) - updated Dec 2024
  @cost_per_1k_tokens %{
    openai: %{input: 0.0015, output: 0.002, models: %{
      "gpt-4o" => %{input: 0.005, output: 0.015},
      "gpt-4o-mini" => %{input: 0.00015, output: 0.0006},
      "gpt-4-turbo" => %{input: 0.01, output: 0.03}
    }},
    anthropic: %{input: 0.003, output: 0.015, models: %{
      "claude-3-opus" => %{input: 0.015, output: 0.075},
      "claude-3-sonnet" => %{input: 0.003, output: 0.015},
      "claude-3-haiku" => %{input: 0.00025, output: 0.00125}
    }},
    ollama: %{input: 0.0, output: 0.0, models: %{}},
    together: %{input: 0.0002, output: 0.0002, models: %{
      "mistral-7b" => %{input: 0.0002, output: 0.0002},
      "llama-70b" => %{input: 0.0009, output: 0.0009}
    }},
    mira: %{input: 0.001, output: 0.001, models: %{}}
  }

  # Task-to-provider recommendations with reasoning
  @task_recommendations %{
    coding: [:anthropic, :openai, :ollama],      # Claude excels at code
    creative: [:anthropic, :openai],              # Best creative writing
    analysis: [:openai, :anthropic],              # Strong analytical reasoning
    local: [:ollama],                             # Privacy/offline requirement
    cheap: [:ollama, :together],                  # Cost-conscious
    fast: [:ollama, :together, :openai],          # Low latency priority
    vision: [:openai, :anthropic],                # Image understanding
    long_context: [:anthropic, :openai]           # Large context windows
  }

  # Circuit breaker states
  @circuit_closed :closed
  @circuit_open :open
  @circuit_half_open :half_open

  defstruct [
    :providers,
    :default_provider,
    :fallback_chain,
    :cost_tracking,
    :cache_enabled,
    :cache_ttl,
    :cache_max_size,
    :stats,
    :cache,
    :cache_order,
    :circuit_breakers,
    :rate_limiters,
    :health_status,
    :health_check_interval,
    :circuit_breaker_threshold,
    :circuit_breaker_timeout
  ]

  @type provider_name :: :openai | :anthropic | :ollama | :together | :mira
  @type task_type :: :coding | :creative | :analysis | :local | :cheap | :fast | :vision | :long_context

  @type call_opts :: [
          provider: provider_name(),
          task: task_type(),
          fallback: [provider_name()],
          model: String.t(),
          cache: boolean(),
          track_cost: boolean(),
          timeout: non_neg_integer()
        ]

  @type provider_stats :: %{
          calls: non_neg_integer(),
          successes: non_neg_integer(),
          failures: non_neg_integer(),
          total_latency_ms: non_neg_integer(),
          avg_latency_ms: float(),
          p50_latency_ms: float(),
          p95_latency_ms: float(),
          p99_latency_ms: float(),
          total_input_tokens: non_neg_integer(),
          total_output_tokens: non_neg_integer(),
          total_cost_usd: float(),
          latencies: [non_neg_integer()]
        }

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

  Handles provider selection, fallback, caching, rate limiting, and circuit breaking.

  ## Options

  - `:provider` - Specific provider to use (bypasses task-based selection)
  - `:task` - Task type for automatic provider selection (:coding, :creative, etc.)
  - `:fallback` - Custom list of fallback providers
  - `:model` - Specific model to use with the provider
  - `:cache` - Whether to cache the result (default: config setting)
  - `:track_cost` - Whether to track costs (default: config setting)
  - `:timeout` - Request timeout in ms (default: 300_000)

  ## Returns

  - `{:ok, Lux.Signal.t()}` on success
  - `{:error, :all_providers_failed}` when all providers fail
  - `{:error, :rate_limited}` when rate limit exceeded
  - `{:error, reason}` for other failures

  ## Examples

      iex> ProviderManager.call("Hello world")
      {:ok, %Lux.Signal{content: "Hello! How can I help you today?"}}

      iex> ProviderManager.call("Write a function", task: :coding)
      {:ok, %Lux.Signal{content: "def hello():\\n  print('Hello')"}}

      iex> ProviderManager.call("Cached query", cache: true)
      {:ok, %Lux.Signal{content: "..."}}  # Returns cached result if available
  """
  @spec call(String.t(), call_opts()) :: {:ok, Signal.t()} | {:error, term()}
  def call(prompt, opts \\ []) do
    call(prompt, [], opts)
  end

  @spec call(String.t(), list(), call_opts()) :: {:ok, Signal.t()} | {:error, term()}
  def call(prompt, tools, opts) when is_list(tools) do
    timeout = Keyword.get(opts, :timeout, :timer.minutes(5))
    GenServer.call(__MODULE__, {:call, prompt, tools, opts}, timeout)
  end

  @doc """
  Lists all registered providers and their current status.

  Returns provider name, module, health status, and circuit breaker state.
  """
  @spec list_providers() :: [{provider_name(), map()}]
  def list_providers do
    GenServer.call(__MODULE__, :list_providers)
  end

  @doc """
  Gets the recommended provider for a task type.

  Considers provider availability, circuit breaker state, and rate limits.
  """
  @spec recommend_provider(task_type()) :: provider_name()
  def recommend_provider(task) do
    GenServer.call(__MODULE__, {:recommend_provider, task})
  end

  @doc """
  Gets comprehensive cost and performance statistics.

  Includes per-provider stats, latency percentiles, and cost breakdown.
  """
  @spec get_stats() :: map()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Resets all statistics to initial values.
  """
  @spec reset_stats() :: :ok
  def reset_stats do
    GenServer.call(__MODULE__, :reset_stats)
  end

  @doc """
  Checks if a provider is currently available.

  Considers health status, circuit breaker state, and rate limits.
  """
  @spec provider_available?(provider_name()) :: boolean()
  def provider_available?(provider) do
    GenServer.call(__MODULE__, {:provider_available?, provider})
  end

  @doc """
  Gets estimated cost for a request based on token counts.

  Supports model-specific pricing when model is specified.
  """
  @spec estimate_cost(provider_name(), non_neg_integer(), non_neg_integer(), String.t() | nil) :: float()
  def estimate_cost(provider, input_tokens, output_tokens, model \\ nil) do
    provider_costs = Map.get(@cost_per_1k_tokens, provider, %{input: 0, output: 0, models: %{}})

    costs = if model && Map.has_key?(provider_costs.models, model) do
      Map.get(provider_costs.models, model)
    else
      %{input: provider_costs.input, output: provider_costs.output}
    end

    (input_tokens / 1000 * costs.input) + (output_tokens / 1000 * costs.output)
  end

  @doc """
  Clears the response cache.
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    GenServer.call(__MODULE__, :clear_cache)
  end

  @doc """
  Gets current cache statistics.
  """
  @spec cache_stats() :: map()
  def cache_stats do
    GenServer.call(__MODULE__, :cache_stats)
  end

  @doc """
  Manually triggers health checks for all providers.
  """
  @spec check_health() :: map()
  def check_health do
    GenServer.call(__MODULE__, :check_health, :timer.seconds(30))
  end

  @doc """
  Resets circuit breaker for a provider.
  """
  @spec reset_circuit_breaker(provider_name()) :: :ok
  def reset_circuit_breaker(provider) do
    GenServer.call(__MODULE__, {:reset_circuit_breaker, provider})
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    config = Application.get_env(:lux, __MODULE__, [])

    state = %__MODULE__{
      providers: @providers,
      default_provider: Keyword.get(config, :default_provider, :openai),
      fallback_chain: Keyword.get(config, :fallback_chain, [:openai, :anthropic, :ollama]),
      cost_tracking: Keyword.get(config, :cost_tracking, true),
      cache_enabled: Keyword.get(config, :cache_enabled, false),
      cache_ttl: Keyword.get(config, :cache_ttl, :timer.hours(1)),
      cache_max_size: Keyword.get(config, :cache_max_size, 1000),
      stats: initial_stats(),
      cache: %{},
      cache_order: [],
      circuit_breakers: initialize_circuit_breakers(),
      rate_limiters: initialize_rate_limiters(config),
      health_status: %{},
      health_check_interval: Keyword.get(config, :health_check_interval, :timer.minutes(5)),
      circuit_breaker_threshold: Keyword.get(config, :circuit_breaker_threshold, 5),
      circuit_breaker_timeout: Keyword.get(config, :circuit_breaker_timeout, :timer.minutes(1))
    }

    # Schedule periodic health checks
    if state.health_check_interval > 0 do
      Process.send_after(self(), :health_check, state.health_check_interval)
    end

    # Schedule rate limiter token refresh
    Process.send_after(self(), :refresh_rate_limits, :timer.seconds(60))

    Logger.info("[ProviderManager] Started with default provider: #{state.default_provider}")
    {:ok, state}
  end

  @impl true
  def handle_call({:call, prompt, tools, opts}, _from, state) do
    start_time = System.monotonic_time(:millisecond)
    cache_key = generate_cache_key(prompt, tools, opts)

    # Check cache first
    case check_cache(cache_key, opts, state) do
      {:hit, cached_result, state} ->
        Logger.debug("[ProviderManager] Cache hit for request")
        state = update_cache_stats(state, :hit)
        {:reply, {:ok, cached_result}, state}

      {:miss, state} ->
        state = update_cache_stats(state, :miss)

        # Determine provider chain
        providers = determine_provider_chain(opts, state)

        # Check rate limits and circuit breakers, then try providers
        case try_providers_with_resilience(providers, prompt, tools, opts, state) do
          {{:ok, signal} = result, state} ->
            elapsed = System.monotonic_time(:millisecond) - start_time
            state = update_stats(state, result, hd(providers), elapsed, signal)
            state = maybe_cache_result(cache_key, signal, opts, state)
            {:reply, result, state}

          {{:error, _reason} = error, state} ->
            elapsed = System.monotonic_time(:millisecond) - start_time
            state = update_stats(state, error, hd(providers), elapsed, nil)
            {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_call(:list_providers, _from, state) do
    providers =
      Enum.map(state.providers, fn {name, module} ->
        circuit_state = Map.get(state.circuit_breakers, name, %{state: @circuit_closed})
        health = Map.get(state.health_status, name, :unknown)
        rate_limit = Map.get(state.rate_limiters, name, %{tokens: 0, max: 0})

        {name, %{
          module: module,
          health: health,
          circuit_breaker: circuit_state.state,
          rate_limit_remaining: rate_limit.tokens,
          rate_limit_max: rate_limit.max
        }}
      end)

    {:reply, providers, state}
  end

  @impl true
  def handle_call({:recommend_provider, task}, _from, state) do
    recommendations = Map.get(@task_recommendations, task, [state.default_provider])

    # Find first available provider considering all factors
    provider =
      Enum.find(recommendations, state.default_provider, fn p ->
        is_provider_usable?(p, state)
      end)

    {:reply, provider, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    # Calculate percentiles for each provider
    stats_with_percentiles =
      Enum.map(state.stats.by_provider, fn {provider, pstats} ->
        percentiles = calculate_percentiles(pstats.latencies)
        {provider, Map.merge(pstats, percentiles)}
      end)
      |> Enum.into(%{})

    full_stats = %{
      state.stats |
      by_provider: stats_with_percentiles,
      cache_hit_rate: calculate_cache_hit_rate(state),
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.stats.started_at)
    }

    {:reply, full_stats, state}
  end

  @impl true
  def handle_call(:reset_stats, _from, state) do
    {:reply, :ok, %{state | stats: initial_stats()}}
  end

  @impl true
  def handle_call({:provider_available?, provider}, _from, state) do
    {:reply, is_provider_usable?(provider, state), state}
  end

  @impl true
  def handle_call(:clear_cache, _from, state) do
    {:reply, :ok, %{state | cache: %{}, cache_order: []}}
  end

  @impl true
  def handle_call(:cache_stats, _from, state) do
    stats = %{
      size: map_size(state.cache),
      max_size: state.cache_max_size,
      hit_rate: calculate_cache_hit_rate(state),
      hits: state.stats.cache_hits,
      misses: state.stats.cache_misses
    }
    {:reply, stats, state}
  end

  @impl true
  def handle_call(:check_health, _from, state) do
    health_status = perform_health_checks(state)
    {:reply, health_status, %{state | health_status: health_status}}
  end

  @impl true
  def handle_call({:reset_circuit_breaker, provider}, _from, state) do
    circuit_breakers = Map.put(state.circuit_breakers, provider, %{
      state: @circuit_closed,
      failures: 0,
      last_failure: nil,
      last_success: DateTime.utc_now()
    })
    {:reply, :ok, %{state | circuit_breakers: circuit_breakers}}
  end

  @impl true
  def handle_info(:health_check, state) do
    health_status = perform_health_checks(state)
    Process.send_after(self(), :health_check, state.health_check_interval)
    {:noreply, %{state | health_status: health_status}}
  end

  @impl true
  def handle_info(:refresh_rate_limits, state) do
    rate_limiters = refresh_rate_limiters(state.rate_limiters)
    Process.send_after(self(), :refresh_rate_limits, :timer.seconds(60))
    {:noreply, %{state | rate_limiters: rate_limiters}}
  end

  @impl true
  def handle_info({:circuit_half_open, provider}, state) do
    circuit_breakers = Map.update!(state.circuit_breakers, provider, fn cb ->
      if cb.state == @circuit_open do
        %{cb | state: @circuit_half_open}
      else
        cb
      end
    end)
    {:noreply, %{state | circuit_breakers: circuit_breakers}}
  end

  # ============================================================================
  # Private Functions - Provider Selection & Execution
  # ============================================================================

  defp determine_provider_chain(opts, state) do
    cond do
      opts[:fallback] -> opts[:fallback]
      opts[:provider] -> [opts[:provider]]
      opts[:task] -> Map.get(@task_recommendations, opts[:task], [state.default_provider])
      true -> state.fallback_chain
    end
  end

  defp try_providers_with_resilience([], _prompt, _tools, _opts, state) do
    {{:error, :all_providers_failed}, state}
  end

  defp try_providers_with_resilience([provider | rest], prompt, tools, opts, state) do
    cond do
      not is_provider_usable?(provider, state) ->
        Logger.debug("[ProviderManager] Skipping #{provider} - not usable")
        try_providers_with_resilience(rest, prompt, tools, opts, state)

      not has_rate_limit_tokens?(provider, state) ->
        Logger.debug("[ProviderManager] Skipping #{provider} - rate limited")
        try_providers_with_resilience(rest, prompt, tools, opts, state)

      true ->
        state = consume_rate_limit_token(provider, state)
        module = Map.get(state.providers, provider)
        config = build_provider_config(provider, opts)

        Logger.debug("[ProviderManager] Trying provider: #{provider}")

        case safe_call(module, prompt, tools, config) do
          {:ok, signal} = result ->
            Logger.debug("[ProviderManager] Provider #{provider} succeeded")
            state = record_circuit_success(provider, state)
            {result, state}

          {:error, reason} = error ->
            Logger.warning("[ProviderManager] Provider #{provider} failed: #{inspect(reason)}")
            state = record_circuit_failure(provider, state)

            if rest == [] do
              {error, state}
            else
              try_providers_with_resilience(rest, prompt, tools, opts, state)
            end
        end
    end
  end

  defp safe_call(module, prompt, tools, config) do
    module.call(prompt, tools, config)
  rescue
    e ->
      Logger.error("[ProviderManager] Provider crashed: #{inspect(e)}")
      {:error, {:provider_crash, e}}
  catch
    :exit, reason ->
      Logger.error("[ProviderManager] Provider exited: #{inspect(reason)}")
      {:error, {:provider_exit, reason}}
  end

  defp build_provider_config(_provider, opts) do
    %{
      json_response: Keyword.get(opts, :json_response, false),
      model: opts[:model],
      temperature: opts[:temperature],
      max_tokens: opts[:max_tokens]
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  # ============================================================================
  # Private Functions - Circuit Breaker
  # ============================================================================

  defp initialize_circuit_breakers do
    Enum.map(@providers, fn {name, _} ->
      {name, %{state: @circuit_closed, failures: 0, last_failure: nil, last_success: nil}}
    end)
    |> Enum.into(%{})
  end

  defp record_circuit_success(provider, state) do
    circuit_breakers = Map.update!(state.circuit_breakers, provider, fn cb ->
      %{cb | state: @circuit_closed, failures: 0, last_success: DateTime.utc_now()}
    end)
    %{state | circuit_breakers: circuit_breakers}
  end

  defp record_circuit_failure(provider, state) do
    circuit_breakers = Map.update!(state.circuit_breakers, provider, fn cb ->
      failures = cb.failures + 1
      new_state = if failures >= state.circuit_breaker_threshold do
        # Schedule transition to half-open
        Process.send_after(self(), {:circuit_half_open, provider}, state.circuit_breaker_timeout)
        @circuit_open
      else
        cb.state
      end
      %{cb | state: new_state, failures: failures, last_failure: DateTime.utc_now()}
    end)
    %{state | circuit_breakers: circuit_breakers}
  end

  defp is_circuit_closed?(provider, state) do
    case Map.get(state.circuit_breakers, provider) do
      %{state: @circuit_closed} -> true
      %{state: @circuit_half_open} -> true  # Allow one attempt
      _ -> false
    end
  end

  # ============================================================================
  # Private Functions - Rate Limiting
  # ============================================================================

  defp initialize_rate_limiters(config) do
    limits = Keyword.get(config, :rate_limit_per_minute, %{
      openai: 60,
      anthropic: 60,
      ollama: 1000,
      together: 60,
      mira: 60
    })

    Enum.map(limits, fn {provider, max} ->
      {provider, %{tokens: max, max: max, last_refresh: DateTime.utc_now()}}
    end)
    |> Enum.into(%{})
  end

  defp refresh_rate_limiters(rate_limiters) do
    Enum.map(rate_limiters, fn {provider, rl} ->
      {provider, %{rl | tokens: rl.max, last_refresh: DateTime.utc_now()}}
    end)
    |> Enum.into(%{})
  end

  defp has_rate_limit_tokens?(provider, state) do
    case Map.get(state.rate_limiters, provider) do
      %{tokens: tokens} when tokens > 0 -> true
      _ -> false
    end
  end

  defp consume_rate_limit_token(provider, state) do
    rate_limiters = Map.update!(state.rate_limiters, provider, fn rl ->
      %{rl | tokens: max(0, rl.tokens - 1)}
    end)
    %{state | rate_limiters: rate_limiters}
  end

  # ============================================================================
  # Private Functions - Health Checks
  # ============================================================================

  defp perform_health_checks(state) do
    Enum.map(state.providers, fn {name, module} ->
      status = check_provider_health(name, module)
      {name, status}
    end)
    |> Enum.into(%{})
  end

  defp check_provider_health(provider, module) do
    case provider do
      :ollama ->
        case module.health_check() do
          :ok -> :healthy
          {:ok, _} -> :healthy
          _ -> :unhealthy
        end

      _ ->
        # For cloud providers, check if API key is configured
        case check_api_key_configured(provider) do
          true -> :healthy
          false -> :unconfigured
        end
    end
  rescue
    _ -> :unhealthy
  end

  defp check_api_key_configured(provider) do
    case provider do
      :openai -> not is_nil(System.get_env("OPENAI_API_KEY"))
      :anthropic -> not is_nil(System.get_env("ANTHROPIC_API_KEY"))
      :together -> not is_nil(System.get_env("TOGETHER_API_KEY"))
      :mira -> not is_nil(System.get_env("MIRA_API_KEY"))
      _ -> true
    end
  end

  defp is_provider_usable?(provider, state) do
    health_ok = Map.get(state.health_status, provider, :unknown) in [:healthy, :unknown]
    circuit_ok = is_circuit_closed?(provider, state)
    has_module = Map.has_key?(state.providers, provider)

    has_module and health_ok and circuit_ok
  end

  # ============================================================================
  # Private Functions - Caching
  # ============================================================================

  defp generate_cache_key(prompt, tools, opts) do
    # Include relevant opts in cache key
    cache_opts = Keyword.take(opts, [:provider, :model, :json_response])
    :crypto.hash(:sha256, :erlang.term_to_binary({prompt, tools, cache_opts}))
    |> Base.encode16(case: :lower)
  end

  defp check_cache(cache_key, opts, state) do
    use_cache = Keyword.get(opts, :cache, state.cache_enabled)

    if use_cache do
      case Map.get(state.cache, cache_key) do
        nil ->
          {:miss, state}

        {result, timestamp} ->
          age = DateTime.diff(DateTime.utc_now(), timestamp, :millisecond)
          if age <= state.cache_ttl do
            {:hit, result, state}
          else
            # Expired - remove from cache
            state = remove_from_cache(cache_key, state)
            {:miss, state}
          end
      end
    else
      {:miss, state}
    end
  end

  defp maybe_cache_result(cache_key, signal, opts, state) do
    use_cache = Keyword.get(opts, :cache, state.cache_enabled)

    if use_cache do
      add_to_cache(cache_key, signal, state)
    else
      state
    end
  end

  defp add_to_cache(cache_key, result, state) do
    # LRU eviction if at capacity
    state = if map_size(state.cache) >= state.cache_max_size do
      evict_oldest_cache_entry(state)
    else
      state
    end

    cache = Map.put(state.cache, cache_key, {result, DateTime.utc_now()})
    cache_order = [cache_key | List.delete(state.cache_order, cache_key)]

    %{state | cache: cache, cache_order: cache_order}
  end

  defp remove_from_cache(cache_key, state) do
    cache = Map.delete(state.cache, cache_key)
    cache_order = List.delete(state.cache_order, cache_key)
    %{state | cache: cache, cache_order: cache_order}
  end

  defp evict_oldest_cache_entry(state) do
    case List.last(state.cache_order) do
      nil -> state
      oldest_key -> remove_from_cache(oldest_key, state)
    end
  end

  defp update_cache_stats(state, :hit) do
    update_in(state.stats.cache_hits, &(&1 + 1))
  end

  defp update_cache_stats(state, :miss) do
    update_in(state.stats.cache_misses, &(&1 + 1))
  end

  defp calculate_cache_hit_rate(state) do
    total = state.stats.cache_hits + state.stats.cache_misses
    if total > 0 do
      Float.round(state.stats.cache_hits / total * 100, 2)
    else
      0.0
    end
  end

  # ============================================================================
  # Private Functions - Statistics
  # ============================================================================

  defp initial_stats do
    %{
      total_calls: 0,
      successful_calls: 0,
      failed_calls: 0,
      total_latency_ms: 0,
      avg_latency_ms: 0.0,
      total_input_tokens: 0,
      total_output_tokens: 0,
      total_cost_usd: 0.0,
      cache_hits: 0,
      cache_misses: 0,
      by_provider: initialize_provider_stats(),
      started_at: DateTime.utc_now(),
      last_call_at: nil
    }
  end

  defp initialize_provider_stats do
    Enum.map(@providers, fn {name, _} ->
      {name, %{
        calls: 0,
        successes: 0,
        failures: 0,
        total_latency_ms: 0,
        avg_latency_ms: 0.0,
        total_input_tokens: 0,
        total_output_tokens: 0,
        total_cost_usd: 0.0,
        latencies: []
      }}
    end)
    |> Enum.into(%{})
  end

  defp update_stats(state, result, provider, elapsed, signal) do
    success = match?({:ok, _}, result)

    # Extract token usage from signal if available
    {input_tokens, output_tokens} = extract_token_usage(signal)
    cost = if signal, do: estimate_cost(provider, input_tokens, output_tokens), else: 0.0

    provider_stats = Map.get(state.stats.by_provider, provider, %{
      calls: 0, successes: 0, failures: 0, total_latency_ms: 0,
      avg_latency_ms: 0.0, total_input_tokens: 0, total_output_tokens: 0,
      total_cost_usd: 0.0, latencies: []
    })

    new_provider_stats = %{
      provider_stats |
      calls: provider_stats.calls + 1,
      successes: provider_stats.successes + if(success, do: 1, else: 0),
      failures: provider_stats.failures + if(success, do: 0, else: 1),
      total_latency_ms: provider_stats.total_latency_ms + elapsed,
      avg_latency_ms: (provider_stats.total_latency_ms + elapsed) / (provider_stats.calls + 1),
      total_input_tokens: provider_stats.total_input_tokens + input_tokens,
      total_output_tokens: provider_stats.total_output_tokens + output_tokens,
      total_cost_usd: provider_stats.total_cost_usd + cost,
      latencies: Enum.take([elapsed | provider_stats.latencies], 1000)  # Keep last 1000
    }

    total_calls = state.stats.total_calls + 1
    total_latency = state.stats.total_latency_ms + elapsed

    new_stats = %{
      state.stats |
      total_calls: total_calls,
      successful_calls: state.stats.successful_calls + if(success, do: 1, else: 0),
      failed_calls: state.stats.failed_calls + if(success, do: 0, else: 1),
      total_latency_ms: total_latency,
      avg_latency_ms: total_latency / total_calls,
      total_input_tokens: state.stats.total_input_tokens + input_tokens,
      total_output_tokens: state.stats.total_output_tokens + output_tokens,
      total_cost_usd: state.stats.total_cost_usd + cost,
      by_provider: Map.put(state.stats.by_provider, provider, new_provider_stats),
      last_call_at: DateTime.utc_now()
    }

    %{state | stats: new_stats}
  end

  defp extract_token_usage(nil), do: {0, 0}
  defp extract_token_usage(%{metadata: %{usage: usage}}) do
    {Map.get(usage, :input_tokens, 0), Map.get(usage, :output_tokens, 0)}
  end
  defp extract_token_usage(%{metadata: metadata}) when is_map(metadata) do
    input = Map.get(metadata, :prompt_tokens, 0) || Map.get(metadata, :input_tokens, 0)
    output = Map.get(metadata, :completion_tokens, 0) || Map.get(metadata, :output_tokens, 0)
    {input, output}
  end
  defp extract_token_usage(_), do: {0, 0}

  defp calculate_percentiles(latencies) when length(latencies) == 0 do
    %{p50_latency_ms: 0.0, p95_latency_ms: 0.0, p99_latency_ms: 0.0}
  end

  defp calculate_percentiles(latencies) do
    sorted = Enum.sort(latencies)
    len = length(sorted)

    %{
      p50_latency_ms: percentile(sorted, len, 0.50),
      p95_latency_ms: percentile(sorted, len, 0.95),
      p99_latency_ms: percentile(sorted, len, 0.99)
    }
  end

  defp percentile(sorted, len, p) do
    index = round(p * (len - 1))
    Enum.at(sorted, index) || 0.0
  end
end
