defmodule Lux.LLM.PerformanceMonitorTest do
  use ExUnit.Case, async: true

  alias Lux.LLM.PerformanceMonitor

  setup do
    PerformanceMonitor.reset_all()
    :ok
  end

  describe "record_request/3" do
    test "records successful request" do
      :ok = PerformanceMonitor.record_request(:openai, 250, :success)

      stats = PerformanceMonitor.get_stats(:openai)

      assert stats.total_requests == 1
      assert stats.successful_requests == 1
      assert stats.failed_requests == 0
    end

    test "records failed request" do
      :ok = PerformanceMonitor.record_request(:openai, 100, :failure)

      stats = PerformanceMonitor.get_stats(:openai)

      assert stats.total_requests == 1
      assert stats.successful_requests == 0
      assert stats.failed_requests == 1
    end

    test "tracks latency" do
      PerformanceMonitor.record_request(:openai, 200, :success)
      PerformanceMonitor.record_request(:openai, 400, :success)

      stats = PerformanceMonitor.get_stats(:openai)

      assert stats.min_latency_ms == 200
      assert stats.max_latency_ms == 400
      assert_in_delta stats.avg_latency_ms, 300.0, 0.1
    end
  end

  describe "get_stats/1" do
    test "returns default stats for unknown provider" do
      stats = PerformanceMonitor.get_stats(:unknown)

      assert stats.total_requests == 0
      assert stats.avg_latency_ms == 0.0
    end
  end

  describe "get_health/1" do
    test "returns healthy for good performance" do
      PerformanceMonitor.record_request(:openai, 100, :success)
      PerformanceMonitor.record_request(:openai, 100, :success)

      assert :healthy == PerformanceMonitor.get_health(:openai)
    end

    test "returns degraded for poor performance" do
      for _ <- 1..6 do
        PerformanceMonitor.record_request(:openai, 100, :failure)
      end

      assert :unhealthy == PerformanceMonitor.get_health(:openai)
    end
  end

  describe "consecutive_failures" do
    test "tracks consecutive failures" do
      PerformanceMonitor.increment_consecutive_failures(:openai)
      PerformanceMonitor.increment_consecutive_failures(:openai)

      stats = PerformanceMonitor.get_stats(:openai)

      assert stats.consecutive_failures == 2
    end

    test "reset_consecutive_failures resets count" do
      PerformanceMonitor.increment_consecutive_failures(:openai)
      PerformanceMonitor.reset_consecutive_failures(:openai)

      stats = PerformanceMonitor.get_stats(:openai)

      assert stats.consecutive_failures == 0
    end
  end

  describe "get_aggregate_stats/0" do
    test "returns aggregate stats" do
      PerformanceMonitor.record_request(:openai, 100, :success)
      PerformanceMonitor.record_request(:anthropic, 200, :success)

      stats = PerformanceMonitor.get_aggregate_stats()

      assert stats.total_requests == 2
      assert stats.providers == 2
    end
  end
end