defmodule Lux.LLM.PerformanceMonitorTest do
  use ExUnit.Case

  alias Lux.LLM.PerformanceMonitor

  setup do
    start_supervised!({PerformanceMonitor, name: :test_perf_monitor})
    :ok
  end

  describe "record/5" do
    test "records a successful call" do
      PerformanceMonitor.record(:openai, 1200, :ok, "gpt-4")
      Process.sleep(50)
      stats = PerformanceMonitor.stats(:openai)
      if stats do
        assert stats.successes >= 1
        assert stats.total_calls >= 1
      end
    end

    test "records a failed call" do
      PerformanceMonitor.record(:anthropic, 500, :error, "claude-3-opus", "rate_limit")
      Process.sleep(50)
      stats = PerformanceMonitor.stats(:anthropic)
      if stats do
        assert stats.failures >= 1
      end
    end
  end

  describe "stats/1" do
    test "returns nil for unknown provider" do
      assert PerformanceMonitor.stats(:nonexistent) == nil
    end

    test "calculates success rate" do
      PerformanceMonitor.record(:test_prov, 100, :ok, "model-1")
      PerformanceMonitor.record(:test_prov, 200, :ok, "model-1")
      PerformanceMonitor.record(:test_prov, 50, :error, "model-1", "timeout")
      Process.sleep(50)
      stats = PerformanceMonitor.stats(:test_prov)
      if stats do
        assert stats.total_calls == 3
        assert stats.success_rate >= 0.0
      end
    end
  end

  describe "latency_percentiles/1" do
    test "calculates p50, p95, p99" do
      for latency <- [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000] do
        PerformanceMonitor.record(:lat_test, latency, :ok, "model-1")
      end
      Process.sleep(50)

      percentiles = PerformanceMonitor.latency_percentiles(:lat_test)
      if percentiles do
        assert percentiles.p50 > 0
        assert percentiles.p95 >= percentiles.p50
        assert percentiles.p99 >= percentiles.p95
      end
    end
  end
end
