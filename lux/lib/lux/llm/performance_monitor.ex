defmodule Lux.LLM.PerformanceMonitor do
  @moduledoc """
  Performance monitoring and analytics for LLM requests.

  Tracks latency, throughput, error rates, and other performance metrics
  across all LLM providers. Provides real-time and historical analytics.

  ## Metrics Tracked

  - Request latency (p50, p95, p99)
  - Error rate per provider
  - Throughput (requests per minute)
  - Token throughput (tokens per second)

  ## Usage

      # Record a completed request
      Lux.LLM.PerformanceMonitor.record_request(:openai, %{
        latency_ms: 450,
        status: :ok,
        input_tokens: 500,
        output_tokens: 200,
        model: "gpt-4o"
      })

      # Get performance analytics
      analytics = Lux.LLM.PerformanceMonitor.analytics()

      # Get provider-specific metrics
      metrics = Lux.LLM.PerformanceMonitor.provider_metrics(:openai)
  """

  use GenServer

  require Logger

  @table_name :lux_llm_performance

  # ── Client API ──────────────────────────────────────────────────────

  @doc """
  Starts the performance monitor process.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Records a completed LLM request for performance tracking.

  ## Parameters

  - `provider` - Provider name (e.g., `:openai`)
  - `metrics` - Map containing:
    - `:latency_ms` - Request duration in milliseconds
    - `:status` - `:ok` or `:error`
    - `:input_tokens` - Number of input tokens (optional)
    - `:output_tokens` - Number of output tokens (optional)
    - `:model` - Model name (optional)
    - `:error_type` - Error classification (optional, when status is :error)
  """
  @spec record_request(atom(), map()) :: :ok
  def record_request(provider, metrics) do
    entry = %{
      provider: provider,
      latency_ms: Map.get(metrics, :latency_ms, 0),
      status: Map.get(metrics, :status, :ok),
      input_tokens: Map.get(metrics, :input_tokens, 0),
      output_tokens: Map.get(metrics, :output_tokens, 0),
      model: Map.get(metrics, :model),
      error_type: Map.get(metrics, :error_type),
      timestamp: System.system_time(:millisecond)
    }

    :ets.insert(@table_name, {make_ref(), entry})
    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc """
  Returns comprehensive analytics across all providers.

  ## Options

  - `:since` - Only include entries after this timestamp (milliseconds)
  - `:window_minutes` - Time window in minutes (default: 60)
  """
  @spec analytics(keyword()) :: map()
  def analytics(opts \\ []) do
    window_minutes = Keyword.get(opts, :window_minutes, 60)
    since = Keyword.get(opts, :since, System.system_time(:millisecond) - window_minutes * 60_000)

    entries = get_entries(since)

    %{
      window_minutes: window_minutes,
      total_requests: length(entries),
      total_errors: Enum.count(entries, &(&1.status == :error)),
      error_rate: error_rate(entries),
      latency: latency_stats(entries),
      throughput: throughput_stats(entries, window_minutes),
      by_provider: per_provider_analytics(entries, window_minutes)
    }
  rescue
    ArgumentError ->
      %{
        window_minutes: 60,
        total_requests: 0,
        total_errors: 0,
        error_rate: 0.0,
        latency: %{p50: 0, p95: 0, p99: 0, avg: 0},
        throughput: %{requests_per_minute: 0.0, tokens_per_second: 0.0},
        by_provider: %{}
      }
  end

  @doc """
  Returns metrics for a specific provider.
  """
  @spec provider_metrics(atom(), keyword()) :: map()
  def provider_metrics(provider, opts \\ []) do
    window_minutes = Keyword.get(opts, :window_minutes, 60)
    since = Keyword.get(opts, :since, System.system_time(:millisecond) - window_minutes * 60_000)

    entries =
      get_entries(since)
      |> Enum.filter(&(&1.provider == provider))

    build_provider_metrics(entries, window_minutes)
  rescue
    ArgumentError ->
      %{
        requests: 0,
        errors: 0,
        error_rate: 0.0,
        latency: %{p50: 0, p95: 0, p99: 0, avg: 0},
        throughput: %{requests_per_minute: 0.0, tokens_per_second: 0.0}
      }
  end

  @doc """
  Resets all performance data.
  """
  @spec reset() :: :ok
  def reset do
    :ets.delete_all_objects(@table_name)
    :ok
  rescue
    ArgumentError -> :ok
  end

  # ── GenServer Callbacks ─────────────────────────────────────────────

  @impl true
  def init(_opts) do
    table = :ets.new(@table_name, [:named_table, :set, :public, write_concurrency: true])
    {:ok, %{table: table}}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ── Private ─────────────────────────────────────────────────────────

  defp get_entries(since) do
    :ets.tab2list(@table_name)
    |> Enum.map(fn {_ref, entry} -> entry end)
    |> Enum.filter(fn entry -> entry.timestamp >= since end)
  rescue
    ArgumentError -> []
  end

  defp error_rate([]), do: 0.0

  defp error_rate(entries) do
    errors = Enum.count(entries, &(&1.status == :error))
    Float.round(errors / length(entries), 4)
  end

  defp latency_stats([]), do: %{p50: 0, p95: 0, p99: 0, avg: 0}

  defp latency_stats(entries) do
    latencies =
      entries
      |> Enum.map(& &1.latency_ms)
      |> Enum.sort()

    n = length(latencies)

    %{
      p50: percentile(latencies, n, 0.50),
      p95: percentile(latencies, n, 0.95),
      p99: percentile(latencies, n, 0.99),
      avg: round(Enum.sum(latencies) / n)
    }
  end

  defp percentile(sorted, n, p) do
    index = max(0, round(n * p) - 1)
    Enum.at(sorted, index, 0)
  end

  defp throughput_stats([], _window), do: %{requests_per_minute: 0.0, tokens_per_second: 0.0}

  defp throughput_stats(entries, window_minutes) do
    total_tokens =
      Enum.reduce(entries, 0, fn e, acc -> acc + e.input_tokens + e.output_tokens end)

    window_seconds = max(1, window_minutes * 60)

    %{
      requests_per_minute: Float.round(length(entries) / max(1, window_minutes), 2),
      tokens_per_second: Float.round(total_tokens / window_seconds, 2)
    }
  end

  defp per_provider_analytics(entries, window_minutes) do
    entries
    |> Enum.group_by(& &1.provider)
    |> Enum.map(fn {provider, provider_entries} ->
      {provider, build_provider_metrics(provider_entries, window_minutes)}
    end)
    |> Map.new()
  end

  defp build_provider_metrics(entries, window_minutes) do
    %{
      requests: length(entries),
      errors: Enum.count(entries, &(&1.status == :error)),
      error_rate: error_rate(entries),
      latency: latency_stats(entries),
      throughput: throughput_stats(entries, window_minutes)
    }
  end
end
