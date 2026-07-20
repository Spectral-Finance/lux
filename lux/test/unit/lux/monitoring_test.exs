defmodule Lux.MonitoringTest do
  use ExUnit.Case, async: true

  alias Lux.Monitoring

  setup do
    Monitoring.reset()
    :ok
  end

  describe "start_link/1" do
    test "starts monitoring server" do
      assert {:ok, pid} = Monitoring.start_link()
      assert is_pid(pid)
    end
  end

  describe "log/3" do
    test "logs info messages" do
      assert :ok = Monitoring.log(:info, "Test message")
      logs = Monitoring.recent_logs(limit: 10)
      assert length(logs) >= 1
      assert hd(logs).message == "Test message"
    end

    test "logs with metadata" do
      assert :ok = Monitoring.log(:warn, "Warning", metadata: %{user_id: "123"})
      logs = Monitoring.recent_logs(level: :warn)
      assert hd(logs).metadata.user_id == "123"
    end

    test "respects log level threshold" do
      assert :ok = Monitoring.log(:debug, "Debug message")
      logs = Monitoring.recent_logs(level: :debug)
      assert logs == []
    end
  end

  describe "record_metric/2" do
    test "records metric values" do
      assert :ok = Monitoring.record_metric("test_metric", value: 42)
      metrics = Monitoring.get_metrics("test_metric")

      assert metrics.count == 1
      assert metrics.sum == 42
      assert metrics.avg == 42
      assert metrics.min == 42
      assert metrics.max == 42
    end

    test "aggregates multiple values" do
      Monitoring.record_metric("latency", value: 100)
      Monitoring.record_metric("latency", value: 200)
      Monitoring.record_metric("latency", value: 300)

      metrics = Monitoring.get_metrics("latency")
      assert metrics.count == 3
      assert metrics.sum == 600
      assert metrics.avg == 200
      assert metrics.min == 100
      assert metrics.max == 300
    end

    test "returns count when aggregation is :count" do
      Monitoring.record_metric("requests", value: 1)
      Monitoring.record_metric("requests", value: 1)

      count = Monitoring.get_metrics("requests", aggregation: :count)
      assert count == 2
    end

    test "returns empty result for unknown metric" do
      result = Monitoring.get_metrics("unknown_metric")
      assert result.count == 0
      assert result.sum == 0
    end
  end

  describe "track/3" do
    test "tracks function execution time" do
      assert {:ok, result} = Monitoring.track("fast_op", fn -> {:ok, 42} end)
      assert result == {:ok, 42}

      metrics = Monitoring.get_metrics("fast_op")
      assert metrics.count == 1
      assert metrics.min >= 0
    end

    test "tracks error results" do
      assert {:error, _} = Monitoring.track("failing_op", fn -> raise "fail" end)
      metrics = Monitoring.get_metrics("failing_op")
      assert metrics.count == 1
    end
  end

  describe "health_status/0" do
    test "returns health status map" do
      status = Monitoring.health_status()

      assert Map.has_key?(status, :status)
      assert Map.has_key?(status, :components)
      assert Map.has_key?(status, :uptime_ms)
      assert Map.has_key?(status, :timestamp)
    end

    test "status is healthy or degraded" do
      status = Monitoring.health_status()
      assert status.status in [:healthy, :degraded]
    end
  end

  describe "recent_logs/1" do
    test "returns recent logs" do
      Monitoring.log(:info, "Log 1")
      Monitoring.log(:info, "Log 2")
      Monitoring.log(:info, "Log 3")

      logs = Monitoring.recent_logs(limit: 2)
      assert length(logs) == 2
    end

    test "filters by level" do
      Monitoring.log(:info, "Info message")
      Monitoring.log(:error, "Error message")

      errors = Monitoring.recent_logs(level: :error)
      assert length(errors) == 1
      assert hd(errors).message == "Error message"
    end
  end

  describe "set_alert_threshold/2" do
    test "configures alert threshold" do
      assert {:ok, config} = Monitoring.set_alert_threshold("error_count", max: 10, window: :minute)

      assert config.name == "error_count"
      assert config.max == 10
      assert config.window == :minute
    end
  end

  describe "export_data/0" do
    test "exports monitoring data" do
      Monitoring.log(:info, "Export test")
      Monitoring.record_metric("export_metric", value: 1)

      data = Monitoring.export_data()

      assert Map.has_key?(data, :metrics)
      assert Map.has_key?(data, :logs)
      assert Map.has_key?(data, :health)
      assert Map.has_key?(data, :exported_at)
    end
  end

  describe "reset/0" do
    test "clears all data" do
      Monitoring.log(:info, "Before reset")
      Monitoring.record_metric("before_reset", value: 1)

      Monitoring.reset()

      logs = Monitoring.recent_logs()
      assert logs == []

      metrics = Monitoring.get_metrics("before_reset")
      assert metrics.count == 0
    end
  end
end
