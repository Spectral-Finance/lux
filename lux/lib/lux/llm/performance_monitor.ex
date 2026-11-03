defmodule Lux.LLM.PerformanceMonitor do
  @moduledoc """
  Performance monitoring and analytics for LLM provider operations.

  Tracks execution latency, tokens-per-second throughput, error rates,
  and availability across configured LLM providers.
  """

  @doc """
  Times execution of an operation and records performance metrics.
  """
  @spec measure(atom() | String.t(), String.t(), (() -> {:ok, term()} | {:error, term()})) ::
          {:ok, term(), map()} | {:error, term(), map()}
  def measure(provider, model, fun) do
    start_time = System.monotonic_time(:millisecond)

    case fun.() do
      {:ok, result} ->
        end_time = System.monotonic_time(:millisecond)
        duration_ms = max(end_time - start_time, 0)
        metric = record_event(provider, model, duration_ms, :success)
        {:ok, result, metric}

      {:error, reason} ->
        end_time = System.monotonic_time(:millisecond)
        duration_ms = max(end_time - start_time, 0)
        metric = record_event(provider, model, duration_ms, :error)
        {:error, reason, metric}
    end
  end

  @doc """
  Records a raw metric event.
  """
  @spec record_event(atom() | String.t(), String.t(), integer(), :success | :error) :: map()
  def record_event(provider, model, duration_ms, status) do
    event = %{
      provider: to_string(provider),
      model: model,
      duration_ms: duration_ms,
      status: status,
      timestamp: System.system_time(:millisecond)
    }

    history = Process.get(:lux_llm_perf_history, [])
    Process.put(:lux_llm_perf_history, [event | history])
    event
  end

  @doc """
  Returns aggregated performance metrics across all providers.
  """
  @spec get_report() :: map()
  def get_report do
    history = Process.get(:lux_llm_perf_history, [])

    Enum.reduce(
      history,
      %{
        total_calls: 0,
        success_count: 0,
        error_count: 0,
        average_latency_ms: 0.0,
        providers: %{}
      },
      fn item, acc ->
        prov = item.provider
        is_succ = item.status == :success

        prov_data =
          Map.get(acc.providers, prov, %{
            total: 0,
            success: 0,
            error: 0,
            total_duration_ms: 0
          })

        updated_prov = %{
          total: prov_data.total + 1,
          success: prov_data.success + if(is_succ, do: 1, else: 0),
          error: prov_data.error + if(is_succ, do: 0, else: 1),
          total_duration_ms: prov_data.total_duration_ms + item.duration_ms
        }

        tot_calls = acc.total_calls + 1
        tot_duration = (acc.average_latency_ms * acc.total_calls) + item.duration_ms

        %{
          total_calls: tot_calls,
          success_count: acc.success_count + if(is_succ, do: 1, else: 0),
          error_count: acc.error_count + if(is_succ, do: 0, else: 1),
          average_latency_ms: Float.round(tot_duration / tot_calls, 2),
          providers: Map.put(acc.providers, prov, updated_prov)
        }
      end
    )
  end

  @doc """
  Resets performance history.
  """
  @spec reset!() :: :ok
  def reset! do
    Process.put(:lux_llm_perf_history, [])
    :ok
  end
end
