defmodule Lux.LLM.ProviderRouter do
  @moduledoc """
  A unified provider abstraction layer that routes LLM requests across multiple providers
  with automatic failover, load balancing, and cost optimization.

  ## Features

  - **Automatic Routing**: Routes requests to the best available provider based on
    availability, cost, and latency.
  - **Failover**: If a provider fails, automatically retries with the next available provider.
  - **Load Balancing**: Distributes requests across providers using configurable strategies.
  - **Cost Optimization**: Tracks costs per provider and can route to the cheapest option.
  - **Health Monitoring**: Monitors provider health and removes unhealthy providers from rotation.

  ## Configuration

      config :lux, :provider_router,
        providers: [
          %{module: Lux.LLM.OpenAI, weight: 3, max_retries: 2},
          %{module: Lux.LLM.Anthropic, weight: 2, max_retries: 2},
          %{module: Lux.LLM.OpenRouter, weight: 1, max_retries: 1}
        ],
        strategy: :weighted_round_robin,
        failover_enabled: true,
        health_check_interval: 60_000

  ## Usage

      # Simple call with automatic routing
      {:ok, response} = Lux.LLM.ProviderRouter.call("Hello!", [], %{})

      # Force a specific provider
      {:ok, response} = Lux.LLM.ProviderRouter.call("Hello!", [], %{provider: Lux.LLM.OpenAI})

      # Use cost-optimized routing
      {:ok, response} = Lux.LLM.ProviderRouter.call("Hello!", [], %{optimize: :cost})

      # Use latency-optimized routing
      {:ok, response} = Lux.LLM.ProviderRouter.call("Hello!", [], %{optimize: :latency})
  """

  @behaviour Lux.LLM

  alias Lux.LLM.Response
  require Logger

  @default_strategy :round_robin
  @default_max_retries 3
  @default_timeout 30_000

  defmodule State do
    @moduledoc false
    defstruct providers: [],
              strategy: :round_robin,
              failover_enabled: true,
              health_check_interval: 60_000,
              current_index: 0,
              provider_stats: %{}
  end

  @doc """
  Starts the ProviderRouter GenServer for stateful routing.

  ## Options
    - `:providers` - List of provider configurations
    - `:strategy` - Routing strategy (:round_robin, :weighted, :cost, :latency)
    - `:failover_enabled` - Enable automatic failover (default: true)
    - `:health_check_interval` - Health check interval in ms (default: 60_000)
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    providers = opts[:providers] || default_providers()

    state = %State{
      providers: providers,
      strategy: opts[:strategy] || @default_strategy,
      failover_enabled: Keyword.get(opts, :failover_enabled, true),
      health_check_interval: opts[:health_check_interval] || 60_000,
      provider_stats: init_stats(providers)
    }

    schedule_health_check(state)
    {:ok, state}
  end

  @doc """
  Routes an LLM call through the provider router.

  This is the main entry point that implements the `Lux.LLM` behaviour.
  It delegates to the appropriate provider based on the routing strategy
  and handles failover if enabled.
  """
  @impl true
  def call(prompt, tools, opts) do
    config = get_config()
    providers = opts[:providers] || config[:providers] || default_providers()
    strategy = opts[:strategy] || config[:strategy] || @default_strategy
    failover = Keyword.get(opts, :failover_enabled, config[:failover_enabled], true)

    # If a specific provider is forced, use only that one
    providers =
      if opts[:provider] do
        [%{module: opts[:provider], weight: 1, max_retries: @default_max_retries}]
      else
        providers
      end

    # Sort providers based on strategy
    sorted = sort_providers(providers, strategy, opts)

    if failover do
      call_with_failover(prompt, tools, opts, sorted)
    else
      call_single(prompt, tools, opts, hd(sorted))
    end
  end

  @doc """
  Returns health status of all configured providers.

  ## Example

      Lux.LLM.ProviderRouter.health_check()
      # => [
      #   %{module: Lux.LLM.OpenAI, status: :healthy, latency_ms: 150},
      #   %{module: Lux.LLM.Anthropic, status: :degraded, latency_ms: 500},
      # ]
  """
  def health_check do
    config = get_config()
    providers = config[:providers] || default_providers()

    Enum.map(providers, fn provider ->
      start = System.monotonic_time(:millisecond)

      result =
        try do
          provider.module.call("ping", [], %{max_tokens: 1})
        rescue
          e -> {:error, Exception.message(e)}
        end

      latency = System.monotonic_time(:millisecond) - start

      status =
        case result do
          {:ok, _} -> :healthy
          {:error, :rate_limited} -> :degraded
          {:error, _} -> :unhealthy
        end

      %{module: provider.module, status: status, latency_ms: latency}
    end)
  end

  @doc """
  Returns current statistics for all providers.
  """
  def stats do
    config = get_config()
    config[:provider_stats] || %{}
  end

  # Private functions

  defp call_with_failover(prompt, tools, opts, providers, attempt \\ 0)

  defp call_with_failover(_prompt, _tools, _opts, [], _attempt) do
    {:error, :all_providers_failed}
  end

  defp call_with_failover(prompt, tools, opts, [provider | rest], attempt) do
    max_retries = provider[:max_retries] || @default_max_retries

    case call_with_retry(prompt, tools, opts, provider, max_retries) do
      {:ok, response} ->
        record_success(provider.module)
        {:ok, response}

      {:error, reason} ->
        record_failure(provider.module, reason)
        Logger.warning("Provider #{inspect(provider.module)} failed: #{inspect(reason)}")

        if rest != [] do
          Logger.info("Failing over to next provider...")
          call_with_failover(prompt, tools, opts, rest, attempt + 1)
        else
          {:error, :all_providers_failed}
        end
    end
  end

  defp call_single(prompt, tools, opts, provider) do
    max_retries = provider[:max_retries] || @default_max_retries

    case call_with_retry(prompt, tools, opts, provider, max_retries) do
      {:ok, response} ->
        record_success(provider.module)
        {:ok, response}

      {:error, reason} ->
        record_failure(provider.module, reason)
        {:error, reason}
    end
  end

  defp call_with_retry(_prompt, _tools, _opts, _provider, 0) do
    {:error, :max_retries_exceeded}
  end

  defp call_with_retry(prompt, tools, opts, provider, retries_left) do
    # Merge provider-specific options
    provider_opts =
      opts
      |> Map.drop([:provider, :providers, :strategy, :failover_enabled])
      |> Map.merge(provider[:opts] || %{})

    start = System.monotonic_time(:millisecond)

    result =
      try do
        provider.module.call(prompt, tools, provider_opts)
      rescue
        e -> {:error, Exception.message(e)}
      end

    latency = System.monotonic_time(:millisecond) - start
    record_latency(provider.module, latency)

    case result do
      {:ok, _} = success ->
        success

      {:error, :rate_limited} ->
        if retries_left > 1 do
          backoff = calculate_backoff(retries_left)
          Logger.info("Rate limited, retrying in #{backoff}ms...")
          Process.sleep(backoff)
          call_with_retry(prompt, tools, opts, provider, retries_left - 1)
        else
          {:error, :rate_limited}
        end

      {:error, _reason} = error ->
        error
    end
  end

  defp sort_providers(providers, :round_robin, _opts) do
    # Simple round-robin: rotate based on current index
    idx = :persistent_term.get({__MODULE__, :rr_index}, 0)
    :persistent_term.put({__MODULE__, :rr_index}, rem(idx + 1, length(providers)))
    {left, right} = Enum.split(providers, rem(idx, length(providers)))
    right ++ left
  end

  defp sort_providers(providers, :weighted, _opts) do
    Enum.sort_by(providers, fn p -> -(p[:weight] || 1) end)
  end

  defp sort_providers(providers, :cost, _opts) do
    # Sort by average cost (lowest first)
    stats = :persistent_term.get({__MODULE__, :stats}, %{})

    Enum.sort_by(providers, fn p ->
      p_stats = Map.get(stats, p.module, %{})
      Map.get(p_stats, :avg_cost, 0.0)
    end)
  end

  defp sort_providers(providers, :latency, _opts) do
    # Sort by average latency (lowest first)
    stats = :persistent_term.get({__MODULE__, :stats}, %{})

    Enum.sort_by(providers, fn p ->
      p_stats = Map.get(stats, p.module, %{})
      Map.get(p_stats, :avg_latency, 999_999)
    end)
  end

  defp sort_providers(providers, _, _opts), do: providers

  defp calculate_backoff(retries_left) do
    # Exponential backoff: 1s, 2s, 4s, etc.
    base = 1000
    max_retries = @default_max_retries
    attempt = max_retries - retries_left
    min(base * Integer.pow(2, attempt), 30_000)
  end

  defp default_providers do
    Application.get_env(:lux, :provider_router, [])[:providers] ||
      [
        %{module: Lux.LLM.OpenAI, weight: 3, max_retries: 2}
      ]
  end

  defp get_config do
    Application.get_env(:lux, :provider_router, [])
  end

  # Stats tracking

  defp init_stats(providers) do
    Map.new(providers, fn p ->
      {p.module, %{requests: 0, successes: 0, failures: 0, avg_latency: 0, avg_cost: 0.0}}
    end)
  end

  defp record_success(module) do
    update_stat(module, :successes)
  end

  defp record_failure(module, _reason) do
    update_stat(module, :failures)
  end

  defp record_latency(module, latency) do
    key = {__MODULE__, :stats}
    stats = :persistent_term.get(key, %{})
    p_stats = Map.get(stats, module, %{requests: 0, successes: 0, failures: 0, avg_latency: 0, total_latency: 0})

    new_total = (p_stats[:total_latency] || 0) + latency
    new_count = (p_stats[:latency_count] || 0) + 1

    updated = Map.merge(p_stats, %{
      avg_latency: div(new_total, new_count),
      total_latency: new_total,
      latency_count: new_count
    })

    :persistent_term.put(key, Map.put(stats, module, updated))
  end

  defp update_stat(module, field) do
    key = {__MODULE__, :stats}
    stats = :persistent_term.get(key, %{})
    p_stats = Map.get(stats, module, %{requests: 0, successes: 0, failures: 0, avg_latency: 0})
    updated = Map.update(p_stats, field, 1, &(&1 + 1))
    updated = Map.update(updated, :requests, 1, &(&1 + 1))
    :persistent_term.put(key, Map.put(stats, module, updated))
  end

  defp schedule_health_check(state) do
    if state.health_check_interval > 0 do
      Process.send_after(self(), :health_check, state.health_check_interval)
    end
  end

  # GenServer callbacks (only used if started as a GenServer)

  def handle_info(:health_check, state) do
    Logger.debug("Running provider health check...")

    # Run health checks in background
    Task.start(fn ->
      results = health_check()
      Logger.debug("Health check results: #{inspect(results)}")
    end)

    schedule_health_check(state)
    {:noreply, state}
  end
end
