defmodule Lux.LLM.PerformanceMonitorTest do
  use UnitCase, async: false

  alias Lux.LLM.PerformanceMonitor

  setup do
    PerformanceMonitor.reset()
    :ok
  end

  describe "record_request/2 and analytics/1" do
    test "records and retrieves analytics" do
      PerformanceMonitor.record_request(:openai, %{
        latency_ms: 500,
        status: :ok,
        input_tokens: 100,
        output_tokens: 50,
        model: "gpt-4o"
      })

      analytics = PerformanceMonitor.analytics(window_minutes: 60)

      assert analytics.total_requests == 1
      assert analytics.total_errors == 0
      assert analytics.error_rate == 0.0
      assert analytics.latency.avg == 500
    end

    test "tracks multiple requests" do
      for latency <- [100, 200, 300, 400, 500] do
        PerformanceMonitor.record_request(:openai, %{
          latency_ms: latency,
          status: :ok,
          input_tokens: 100,
          output_tokens: 50,
          model: "gpt-4o"
        })
      end

      analytics = PerformanceMonitor.analytics()

      assert analytics.total_requests == 5
      assert analytics.latency.avg == 300
      assert analytics.latency.p50 == 300
    end

    test "tracks errors" do
      PerformanceMonitor.record_request(:openai, %{
        latency_ms: 100,
        status: :ok,
        model: "gpt-4o"
      })

      PerformanceMonitor.record_request(:openai, %{
        latency_ms: 500,
        status: :error,
        error_type: :timeout,
        model: "gpt-4o"
      })

      analytics = PerformanceMonitor.analytics()

      assert analytics.total_requests == 2
      assert analytics.total_errors == 1
      assert_in_delta analytics.error_rate, 0.5, 0.01
    end

    test "calculates throughput" do
      for _ <- 1..10 do
        PerformanceMonitor.record_request(:openai, %{
          latency_ms: 100,
          status: :ok,
          input_tokens: 100,
          output_tokens: 50,
          model: "gpt-4o"
        })
      end

      analytics = PerformanceMonitor.analytics(window_minutes: 60)

      assert analytics.throughput.requests_per_minute > 0
      assert analytics.throughput.tokens_per_second > 0
    end
  end

  describe "per-provider analytics" do
    test "breaks down by provider" do
      for _ <- 1..5 do
        PerformanceMonitor.record_request(:openai, %{
          latency_ms: 200,
          status: :ok,
          model: "gpt-4o"
        })
      end

      for _ <- 1..3 do
        PerformanceMonitor.record_request(:anthropic, %{
          latency_ms: 400,
          status: :ok,
          model: "claude"
        })
      end

      analytics = PerformanceMonitor.analytics()

      assert Map.has_key?(analytics.by_provider, :openai)
      assert Map.has_key?(analytics.by_provider, :anthropic)
      assert analytics.by_provider[:openai].requests == 5
      assert analytics.by_provider[:anthropic].requests == 3
    end
  end

  describe "provider_metrics/2" do
    test "returns metrics for specific provider" do
      PerformanceMonitor.record_request(:openai, %{
        latency_ms: 200,
        status: :ok,
        model: "gpt-4o"
      })

      PerformanceMonitor.record_request(:openai, %{
        latency_ms: 300,
        status: :ok,
        model: "gpt-4o"
      })

      metrics = PerformanceMonitor.provider_metrics(:openai)

      assert metrics.requests == 2
      assert metrics.errors == 0
      assert metrics.error_rate == 0.0
      assert metrics.latency.avg == 250
    end

    test "returns empty metrics for unknown provider" do
      metrics = PerformanceMonitor.provider_metrics(:unknown_provider)

      assert metrics.requests == 0
      assert metrics.error_rate == 0.0
    end
  end

  describe "latency percentiles" do
    test "calculates p50, p95, p99 correctly" do
      # Record 100 requests with varying latencies
      for i <- 1..100 do
        PerformanceMonitor.record_request(:openai, %{
          latency_ms: i * 10,
          status: :ok,
          model: "gpt-4o"
        })
      end

      analytics = PerformanceMonitor.analytics()

      # p50 should be around 500ms (50th request = 500ms)
      assert analytics.latency.p50 > 0
      # p95 should be around 950ms
      assert analytics.latency.p95 > analytics.latency.p50
      # p99 should be around 990ms
      assert analytics.latency.p99 >= analytics.latency.p95
    end
  end

  describe "reset/0" do
    test "clears all performance data" do
      PerformanceMonitor.record_request(:openai, %{
        latency_ms: 200,
        status: :ok,
        model: "gpt-4o"
      })

      PerformanceMonitor.reset()

      analytics = PerformanceMonitor.analytics()
      assert analytics.total_requests == 0
    end
  end
end
