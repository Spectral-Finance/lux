defmodule Lux.Integrations.Telegram.Analytics.PerformanceMonitor do
  @moduledoc """
  Performance and reliability monitoring engine for Telegram bots.
  Calculates latency percentiles (p50, p90, p95, p99), error rates,
  and triggers threshold breach alerts.
  """

  @default_thresholds %{
    max_error_rate_percent: 5.0,
    max_p95_latency_ms: 2000,
    max_rate_limit_errors: 3
  }

  @doc """
  Evaluates performance and error metrics over telemetry events.
  """
  @spec analyze(list(map()), map()) :: map()
  def analyze(events, custom_thresholds \\ %{}) when is_list(events) do
    thresholds = Map.merge(@default_thresholds, custom_thresholds)
    total_events = length(events)

    latencies =
      events
      |> Enum.map(& &1.latency_ms)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort()

    latency_stats = calculate_latency_stats(latencies)

    error_events = Enum.filter(events, &(&1.status == :error))
    total_errors = length(error_events)

    error_rate =
      if total_events > 0 do
        Float.round(total_errors / total_events * 100.0, 2)
      else
        0.0
      end

    error_breakdown =
      error_events
      |> Enum.frequencies_by(fn e -> e.error_code || 500 end)

    rate_limit_count = Map.get(error_breakdown, 429, 0)

    alerts = detect_alerts(error_rate, latency_stats.p95, rate_limit_count, thresholds)

    %{
      total_events_measured: total_events,
      total_errors: total_errors,
      error_rate_percent: error_rate,
      rate_limit_429_count: rate_limit_count,
      error_code_distribution: error_breakdown,
      latency: latency_stats,
      alerts: alerts
    }
  end

  defp calculate_latency_stats([]) do
    %{min_ms: 0, max_ms: 0, avg_ms: 0.0, p50: 0, p90: 0, p95: 0, p99: 0}
  end

  defp calculate_latency_stats(sorted) do
    count = length(sorted)
    sum = Enum.sum(sorted)

    %{
      min_ms: hd(sorted),
      max_ms: List.last(sorted),
      avg_ms: Float.round(sum / count, 1),
      p50: percentile(sorted, 0.50),
      p90: percentile(sorted, 0.90),
      p95: percentile(sorted, 0.95),
      p99: percentile(sorted, 0.99)
    }
  end

  defp percentile(sorted, p) do
    idx = round((length(sorted) - 1) * p)
    Enum.at(sorted, idx)
  end

  defp detect_alerts(error_rate, p95, rate_limits, thresholds) do
    alerts = []

    alerts =
      if error_rate > thresholds.max_error_rate_percent do
        [
          %{
            level: :critical,
            metric: :error_rate,
            current_value: error_rate,
            threshold: thresholds.max_error_rate_percent,
            message: "Error rate (#{error_rate}%) exceeds threshold of #{thresholds.max_error_rate_percent}%"
          }
          | alerts
        ]
      else
        alerts
      end

    alerts =
      if p95 > thresholds.max_p95_latency_ms do
        [
          %{
            level: :warning,
            metric: :p95_latency,
            current_value: p95,
            threshold: thresholds.max_p95_latency_ms,
            message: "p95 latency (#{p95}ms) exceeds threshold of #{thresholds.max_p95_latency_ms}ms"
          }
          | alerts
        ]
      else
        alerts
      end

    if rate_limits > thresholds.max_rate_limit_errors do
      [
        %{
          level: :critical,
          metric: :rate_limit_exceeded,
          current_value: rate_limits,
          threshold: thresholds.max_rate_limit_errors,
          message: "Telegram API 429 rate limits encountered (#{rate_limits} hits)"
        }
        | alerts
      ]
    else
      alerts
    end
  end
end
