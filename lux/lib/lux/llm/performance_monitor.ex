defmodule Lux.LLM.PerformanceMonitor do
  @moduledoc """
  Monitors LLM provider performance.

  Tracks:
  - Request latency
  - Success/failure rates
  - Throughput
  - Error patterns

  ## Usage

      # Record a request
      PerformanceMonitor.record_request(:openai, 250, :success)

      # Get stats for a provider
      stats = PerformanceMonitor.get_stats(:openai)

      # Get all stats
      all_stats = PerformanceMonitor.get_all_stats()

  """

  use Agent

  @table_name :lux_llm_performance_monitor

  @doc """
  Start the performance monitor agent.
  """
  def start_link(_opts \\ []) do
    Agent.start_link(fn -> init_monitor() end, name: __MODULE__)
  end

  @doc """
  Record a request result.

  ## Parameters

    * `provider` - The LLM provider
    * `latency_ms` - Request latency in milliseconds
    * `result` - :success or :failure

  ## Examples

      iex> PerformanceMonitor.record_request(:openai, 250, :success)
      :ok

  """
  @spec record_request(atom(), non_neg_integer(), :success | :failure) :: :ok
  def record_request(provider, latency_ms, result) do
    Agent.update(__MODULE__, fn state ->
      now = System.monotonic_time(:millisecond)

      # Get current stats
      current = case :ets.lookup(@table_name, {:stats, provider}) do
        [{_, data}] -> data
        [] -> default_stats()
      end

      # Update stats
      updated = %{
        total_requests: current.total_requests + 1,
        successful_requests: current.successful_requests + if(result == :success, do: 1, else: 0),
        failed_requests: current.failed_requests + if(result == :failure, do: 1, else: 0),
        total_latency_ms: current.total_latency_ms + latency_ms,
        min_latency_ms: min(current.min_latency_ms || latency_ms, latency_ms),
        max_latency_ms: max(current.max_latency_ms || latency_ms, latency_ms),
        avg_latency_ms: nil,  # Calculated on demand
        last_request_time: now,
        consecutive_failures: if(result == :failure, do: current.consecutive_failures + 1, else: 0),
        last_failure_time: if(result == :failure, do: now, else: current.last_failure_time)
      }

      :ets.insert(@table_name, {{:stats, provider}, updated})

      Map.put(state, provider, updated)
    end)
  end

  @doc """
  Get performance stats for a provider.

  ## Examples

      iex> PerformanceMonitor.get_stats(:openai)
      %{total_requests: 100, avg_latency_ms: 250, ...}

  """
  @spec get_stats(atom()) :: map()
  def get_stats(provider) do
    case :ets.lookup(@table_name, {:stats, provider}) do
      [{_, data}] -> calculate_derived_stats(data)
      [] -> default_stats()
    end
  end

  @doc """
  Get stats for all providers.

  ## Examples

      iex> PerformanceMonitor.get_all_stats()
      %{openai: %{...}, anthropic: %{...}}

  """
  @spec get_all_stats() :: map()
  def get_all_stats do
    :ets.tab2list(@table_name)
    |> Enum.filter(fn
      {{:stats, _}, _} -> true
      _ -> false
    end)
    |> Enum.map(fn {{:stats, provider}, data} -> {provider, calculate_derived_stats(data)} end)
    |> Map.new()
  end

  @doc """
  Reset stats for a provider.

  ## Examples

      iex> PerformanceMonitor.reset(:openai)
      :ok

  """
  @spec reset(atom()) :: :ok
  def reset(provider) do
    Agent.update(__MODULE__, fn state ->
      :ets.insert(@table_name, {{:stats, provider}, default_stats()})
      Map.put(state, provider, default_stats())
    end)
  end

  @doc """
  Reset all stats.

  ## Examples

      iex> PerformanceMonitor.reset_all()
      :ok

  """
  @spec reset_all() :: :ok
  def reset_all do
    Agent.update(__MODULE__, fn state ->
      :ets.delete_all_objects(@table_name)
      state
    end)
  end

  @doc """
  Increment consecutive failures for a provider.

  ## Examples

      iex> PerformanceMonitor.increment_consecutive_failures(:openai)
      :ok

  """
  @spec increment_consecutive_failures(atom()) :: :ok
  def increment_consecutive_failures(provider) do
    Agent.update(__MODULE__, fn state ->
      current = case :ets.lookup(@table_name, {:stats, provider}) do
        [{_, data}] -> data
        [] -> default_stats()
      end

      updated = %{current |
        consecutive_failures: current.consecutive_failures + 1,
        last_failure_time: System.monotonic_time(:millisecond)
      }

      :ets.insert(@table_name, {{:stats, provider}, updated})
      Map.put(state, provider, updated)
    end)
  end

  @doc """
  Reset consecutive failures for a provider.

  ## Examples

      iex> PerformanceMonitor.reset_consecutive_failures(:openai)
      :ok

  """
  @spec reset_consecutive_failures(atom()) :: :ok
  def reset_consecutive_failures(provider) do
    Agent.update(__MODULE__, fn state ->
      current = case :ets.lookup(@table_name, {:stats, provider}) do
        [{_, data}] -> data
        [] -> default_stats()
      end

      updated = %{current | consecutive_failures: 0}
      :ets.insert(@table_name, {{:stats, provider}, updated})
      Map.put(state, provider, updated)
    end)
  end

  @doc """
  Get health status for a provider.

  ## Examples

      iex> PerformanceMonitor.get_health(:openai)
      :healthy

  """
  @spec get_health(atom()) :: :healthy | :degraded | :unhealthy
  def get_health(provider) do
    stats = get_stats(provider)

    success_rate = if stats.total_requests > 0 do
      stats.successful_requests / stats.total_requests
    else
      1.0
    end

    cond do
      stats.consecutive_failures >= 5 -> :unhealthy
      success_rate < 0.5 -> :degraded
      success_rate < 0.8 -> :degraded
      true -> :healthy
    end
  end

  @doc """
  Get aggregate stats.

  ## Examples

      iex> PerformanceMonitor.get_aggregate_stats()
      %{total_requests: 500, avg_latency_ms: 200, ...}

  """
  @spec get_aggregate_stats() :: map()
  def get_aggregate_stats do
    all_stats = get_all_stats()

    if map_size(all_stats) == 0 do
      default_stats()
    else
      values = Map.values(all_stats)

      total_requests = Enum.reduce(values, 0, fn s, acc -> acc + s.total_requests end)
      total_successful = Enum.reduce(values, 0, fn s, acc -> acc + s.successful_requests end)
      total_failed = Enum.reduce(values, 0, fn s, acc -> acc + s.failed_requests end)
      total_latency = Enum.reduce(values, 0, fn s, acc -> acc + (s.total_latency_ms || 0) end)

      %{
        total_requests: total_requests,
        successful_requests: total_successful,
        failed_requests: total_failed,
        success_rate: if(total_requests > 0, do: total_successful / total_requests, else: 0.0),
        avg_latency_ms: if(total_requests > 0, do: total_latency / total_requests, else: 0.0),
        providers: map_size(all_stats)
      }
    end
  end

  # Private functions

  defp init_monitor do
    if :ets.whereis(@table_name) == :undefined do
      :ets.new(@table_name, [:named_table, :set, :public])
    end
    %{}
  end

  defp default_stats do
    %{
      total_requests: 0,
      successful_requests: 0,
      failed_requests: 0,
      total_latency_ms: 0,
      min_latency_ms: nil,
      max_latency_ms: nil,
      avg_latency_ms: 0.0,
      last_request_time: nil,
      consecutive_failures: 0,
      last_failure_time: nil
    }
  end

  defp calculate_derived_stats(data) do
    avg = if data.total_requests > 0 do
      data.total_latency_ms / data.total_requests
    else
      0.0
    end

    success_rate = if data.total_requests > 0 do
      data.successful_requests / data.total_requests
    else
      0.0
    end

    Map.merge(data, %{
      avg_latency_ms: Float.round(avg, 2),
      success_rate: Float.round(success_rate, 4)
    })
  end
end