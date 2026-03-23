defmodule Lux.Prisms.Telegram.Analytics.CustomMetricsTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Integrations.Telegram.Analytics.Collector
  alias Lux.Prisms.Telegram.Analytics.CustomMetrics

  @agent_ctx %{name: "TestAgent"}

  setup do
    {:ok, pid} = Collector.start_link(name: Collector)

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    :ok
  end

  describe "handler/2" do
    test "records a custom metric successfully" do
      params = %{
        metric_name: "api_latency",
        metric_value: 150.5
      }

      assert {:ok, result} = CustomMetrics.handler(params, @agent_ctx)

      assert result.recorded == true
      assert is_binary(result.metric_id)
      assert result.metric_name == "api_latency"
    end

    test "records a metric with tags" do
      params = %{
        metric_name: "cpu_usage",
        metric_value: 75.0,
        tags: %{region: "us-east", host: "server-1"}
      }

      assert {:ok, result} = CustomMetrics.handler(params, @agent_ctx)

      assert result.recorded == true
      assert result.metric_name == "cpu_usage"
    end

    test "stores metric in collector" do
      params = %{
        metric_name: "memory_usage",
        metric_value: 2048
      }

      assert {:ok, _result} = CustomMetrics.handler(params, @agent_ctx)

      :timer.sleep(20)

      stats = Collector.get_stats()
      assert length(stats.custom_metrics) == 1

      metric = hd(stats.custom_metrics)
      assert metric.metric_name == "memory_usage"
      assert metric.metric_value == 2048
    end

    test "returns error for missing metric_name" do
      params = %{metric_value: 100}

      assert {:error, _message} = CustomMetrics.handler(params, @agent_ctx)
    end

    test "returns error for missing metric_value" do
      params = %{metric_name: "test"}

      assert {:error, _message} = CustomMetrics.handler(params, @agent_ctx)
    end

    test "returns error for non-numeric metric_value" do
      params = %{metric_name: "test", metric_value: "not_a_number"}

      assert {:error, _message} = CustomMetrics.handler(params, @agent_ctx)
    end

    test "generates unique metric IDs" do
      params = %{metric_name: "test", metric_value: 1.0}

      {:ok, result1} = CustomMetrics.handler(params, @agent_ctx)
      {:ok, result2} = CustomMetrics.handler(params, @agent_ctx)

      assert result1.metric_id != result2.metric_id
    end

    test "defaults to empty tags when not provided" do
      params = %{metric_name: "test_metric", metric_value: 42}

      assert {:ok, _result} = CustomMetrics.handler(params, @agent_ctx)

      :timer.sleep(20)

      stats = Collector.get_stats()
      metric = hd(stats.custom_metrics)
      assert metric.tags == %{}
    end
  end
end
