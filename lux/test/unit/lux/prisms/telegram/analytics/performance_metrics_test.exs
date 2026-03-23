defmodule Lux.Prisms.Telegram.Analytics.PerformanceMetricsTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Integrations.Telegram.Analytics.Collector
  alias Lux.Prisms.Telegram.Analytics.PerformanceMetrics

  @agent_ctx %{name: "TestAgent"}

  setup do
    {:ok, pid} = Collector.start_link(name: Collector)

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    :ok
  end

  describe "handler/2" do
    test "returns performance metrics with no data" do
      assert {:ok, result} = PerformanceMetrics.handler(%{}, @agent_ctx)

      assert result.avg_response_time == 0.0
      assert result.p50 == 0
      assert result.p95 == 0
      assert result.p99 == 0
      assert result.min == 0
      assert result.max == 0
      assert result.by_endpoint == %{}
    end

    test "calculates correct aggregate metrics" do
      Collector.track_response_time("/sendMessage", 100)
      Collector.track_response_time("/sendMessage", 200)
      Collector.track_response_time("/sendMessage", 300)

      :timer.sleep(20)

      assert {:ok, result} = PerformanceMetrics.handler(%{}, @agent_ctx)

      assert result.avg_response_time == 200.0
      assert result.min == 100
      assert result.max == 300
      assert is_number(result.p50)
      assert is_number(result.p95)
      assert is_number(result.p99)
    end

    test "breaks down by endpoint" do
      Collector.track_response_time("/sendMessage", 100)
      Collector.track_response_time("/sendMessage", 200)
      Collector.track_response_time("/getUpdates", 50)

      :timer.sleep(20)

      assert {:ok, result} = PerformanceMetrics.handler(%{}, @agent_ctx)

      assert Map.has_key?(result.by_endpoint, "/sendMessage")
      assert Map.has_key?(result.by_endpoint, "/getUpdates")

      send_stats = result.by_endpoint["/sendMessage"]
      assert send_stats.avg_response_time == 150.0
      assert send_stats.min == 100
      assert send_stats.max == 200

      get_stats = result.by_endpoint["/getUpdates"]
      assert get_stats.avg_response_time == 50.0
    end

    test "filters by endpoint" do
      Collector.track_response_time("/sendMessage", 100)
      Collector.track_response_time("/getUpdates", 50)

      :timer.sleep(20)

      assert {:ok, result} = PerformanceMetrics.handler(%{endpoint: "/sendMessage"}, @agent_ctx)

      assert result.avg_response_time == 100.0
      assert map_size(result.by_endpoint) == 1
    end

    test "calculates percentiles correctly with many data points" do
      for i <- 1..100 do
        Collector.track_response_time("/sendMessage", i * 10)
      end

      :timer.sleep(50)

      assert {:ok, result} = PerformanceMetrics.handler(%{}, @agent_ctx)

      assert result.p50 > 0
      assert result.p95 > result.p50
      assert result.p99 >= result.p95
      assert result.min == 10
      assert result.max == 1000
    end
  end
end
