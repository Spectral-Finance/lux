defmodule Lux.LLM.PerformanceMonitor do
  @moduledoc """
  Monitors LLM provider performance: latency, success rates, throughput.

  Provides real-time metrics via Telemetry events and queryable
  statistics for adaptive provider selection.

  ## Tracked Metrics

  - Request latency (p50, p95, p99)
  - Success/failure rates per provider
  - Throughput (requests per minute)
  - Error classification by type

  ## Usage

      # Start monitoring (add to supervision tree)
      children = [{Lux.LLM.PerformanceMonitor, []}]

      # Record a call
      Lux.LLM.PerformanceMonitor.record(:openai, 1250, :ok, "gpt-4")

      # Get stats
      Lux.LLM.PerformanceMonitor.stats(:openai)
      Lux.LLM.PerformanceMonitor.stats()
  """

  use GenServer

  @table :lux_llm_perf_monitor

  # Client API

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Record a completed LLM call with its latency and status.
  """
  @spec record(atom(), non_neg_integer(), :ok | :error, String.t(), term()) :: :ok
  def record(provider, latency_ms, status, model \\ "unknown", error \\ nil) do
    GenServer.cast(__MODULE__, {:record, provider, latency_ms, status, model, error})
  end

  @doc """
  Get performance stats for a specific provider.
  """
  @spec stats(atom()) :: map() | nil
  def stats(provider) do
    GenServer.call(__MODULE__, {:stats, provider})
  end

  @doc """
  Get performance stats for all providers.
  """
  @spec stats() :: %{atom() => map()}
  def stats do
    GenServer.call(__MODULE__, :stats_all)
  end

  @doc """
  Get the best-performing provider based on a composite score.
  """
  @spec best_provider() :: atom() | nil
  def best_provider do
    GenServer.call(__MODULE__, :best_provider)
  end

  @doc """
  Get latency percentiles for a provider.
  """
  @spec latency_percentiles(atom()) :: %{p50: float(), p95: float(), p99: float()} | nil
  def latency_percentiles(provider) do
    GenServer.call(__MODULE__, {:latency_percentiles, provider})
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    state = %{
      providers: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:record, provider, latency_ms, status, model, error}, state) do
    entry = Map.get(state.providers, provider, empty_stats())

    new_latencies = entry.latencies ++ [latency_ms]
    # Keep only last 1000 latency samples
    new_latencies = Enum.take(new_latencies, -1000)

    new_entry = %{entry |
      total_calls: entry.total_calls + 1,
      successes: entry.successes + if(status == :ok, do: 1, else: 0),
      failures: entry.failures + if(status == :error, do: 1, else: 0),
      latencies: new_latencies,
      models: update_model_stats(entry.models, model, status),
      last_error: if(status == :error, do: error, else: entry.last_error),
      last_call_at: DateTime.utc_now()
    }

    # Emit telemetry event
    :telemetry.execute(
      [:lux, :llm, :call],
      %{latency: latency_ms},
      %{provider: provider, model: model, status: status}
    )

    {:noreply, %{state | providers: Map.put(state.providers, provider, new_entry)}}
  end

  @impl true
  def handle_call({:stats, provider}, _from, state) do
    result = Map.get(state.providers, provider)
    {:reply, if(result, do: compute_public_stats(result), else: nil), state}
  end

  def handle_call(:stats_all, _from, state) do
    result = state.providers
    |> Enum.map(fn {k, v} -> {k, compute_public_stats(v)} end)
    |> Map.new()

    {:reply, result, state}
  end

  def handle_call(:best_provider, _from, state) do
    result =
      state.providers
      |> Enum.map(fn {id, stats} -> {id, compute_score(stats)} end)
      |> Enum.filter(fn {_, score} -> score > 0 end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> List.first()

    {:reply, if(result, do: elem(result, 0), else: nil), state}
  end

  def handle_call({:latency_percentiles, provider}, _from, state) do
    case Map.get(state.providers, provider) do
      nil -> {:reply, nil, state}
      stats ->
        latencies = stats.latencies
        {:reply, %{
          p50: percentile(latencies, 0.50),
          p95: percentile(latencies, 0.95),
          p99: percentile(latencies, 0.99)
        }, state}
    end
  end

  # Private

  defp empty_stats do
    %{
      total_calls: 0,
      successes: 0,
      failures: 0,
      latencies: [],
      models: %{},
      last_error: nil,
      last_call_at: nil
    }
  end

  defp update_model_stats(models, model, status) do
    entry = Map.get(models, model, %{calls: 0, successes: 0})
    new_entry = %{entry |
      calls: entry.calls + 1,
      successes: entry.successes + if(status == :ok, do: 1, else: 0)
    }
    Map.put(models, model, new_entry)
  end

  defp compute_public_stats(entry) do
    total = max(entry.total_calls, 1)
    %{
      total_calls: entry.total_calls,
      successes: entry.successes,
      failures: entry.failures,
      success_rate: Float.round(entry.successes / total, 4),
      avg_latency_ms: if(entry.latencies != [], do: round(Enum.sum(entry.latencies) / length(entry.latencies)), else: 0),
      p50_latency_ms: percentile(entry.latencies, 0.50),
      p95_latency_ms: percentile(entry.latencies, 0.95),
      models: entry.models,
      last_error: entry.last_error,
      last_call_at: entry.last_call_at
    }
  end

  defp compute_score(stats) do
    total = max(stats.total_calls, 1)
    success_rate = stats.successes / total
    avg_latency = if stats.latencies != [], do: Enum.sum(stats.latencies) / length(stats.latencies), else: 10_000)

    # Higher is better: success_rate * (1 / normalized_latency)
    # Normalize latency: 1000ms = 1.0, lower is better
    latency_factor = 1.0 / (avg_latency / 1000.0 + 0.1)

    success_rate * latency_factor
  end

  defp percentile([], _), do: 0
  defp percentile(list, p) do
    sorted = Enum.sort(list)
    count = length(sorted)
    rank = p * (count - 1)
    lower = floor(rank)
    upper = ceil(rank)

    if lower == upper do
      Enum.at(sorted, lower, 0)
    else
      lower_val = Enum.at(sorted, lower, 0)
      upper_val = Enum.at(sorted, upper, 0)
      lower_val + (upper_val - lower_val) * (rank - lower)
    end
  end
end
