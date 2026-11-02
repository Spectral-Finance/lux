defmodule Lux.Integrations.Telegram.Analytics.PerformanceMonitorTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.Analytics.PerformanceMonitor

  describe "PerformanceMonitor" do
    test "calculates latency percentiles and error metrics" do
      events = [
        %{status: :success, latency_ms: 10, error_code: nil},
        %{status: :success, latency_ms: 20, error_code: nil},
        %{status: :success, latency_ms: 30, error_code: nil},
        %{status: :success, latency_ms: 40, error_code: nil},
        %{status: :error, latency_ms: 50, error_code: 429}
      ]

      result = PerformanceMonitor.analyze(events)
      assert result.total_events_measured == 5
      assert result.total_errors == 1
      assert result.error_rate_percent == 20.0
      assert result.rate_limit_429_count == 1
      assert result.latency.min_ms == 10
      assert result.latency.max_ms == 50
      assert result.latency.avg_ms == 30.0
    end

    test "detects alerts on threshold violations" do
      events = [
        %{status: :error, latency_ms: 2500, error_code: 429},
        %{status: :error, latency_ms: 2500, error_code: 429},
        %{status: :error, latency_ms: 2500, error_code: 429},
        %{status: :error, latency_ms: 2500, error_code: 429}
      ]

      thresholds = %{
        max_error_rate_percent: 5.0,
        max_p95_latency_ms: 2000,
        max_rate_limit_errors: 3
      }

      result = PerformanceMonitor.analyze(events, thresholds)
      assert length(result.alerts) == 3
      alert_metrics = Enum.map(result.alerts, & &1.metric)
      assert :error_rate in alert_metrics
      assert :p95_latency in alert_metrics
      assert :rate_limit_exceeded in alert_metrics
    end
  end
end
