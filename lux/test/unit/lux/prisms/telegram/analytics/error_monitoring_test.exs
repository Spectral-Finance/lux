defmodule Lux.Prisms.Telegram.Analytics.ErrorMonitoringTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Integrations.Telegram.Analytics.Collector
  alias Lux.Prisms.Telegram.Analytics.ErrorMonitoring

  @agent_ctx %{name: "TestAgent"}

  setup do
    {:ok, pid} = Collector.start_link(name: Collector)

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    :ok
  end

  describe "handler/2" do
    test "returns error monitoring data with no errors" do
      assert {:ok, result} = ErrorMonitoring.handler(%{}, @agent_ctx)

      assert result.total_errors == 0
      assert result.error_rate == 0.0
      assert result.errors_by_type == %{}
      assert result.errors_by_endpoint == %{}
      assert result.error_trend == "stable"
    end

    test "returns correct error totals and breakdown" do
      now = DateTime.utc_now()

      Collector.track_error(%{type: :timeout, endpoint: "/sendMessage", timestamp: now})
      Collector.track_error(%{type: :timeout, endpoint: "/getUpdates", timestamp: now})
      Collector.track_error(%{type: :rate_limit, endpoint: "/sendMessage", timestamp: now})

      :timer.sleep(20)

      assert {:ok, result} = ErrorMonitoring.handler(%{}, @agent_ctx)

      assert result.total_errors == 3
      assert result.errors_by_type[:timeout] == 2
      assert result.errors_by_type[:rate_limit] == 1
      assert result.errors_by_endpoint["/sendMessage"] == 2
      assert result.errors_by_endpoint["/getUpdates"] == 1
    end

    test "filters by time range" do
      t1 = ~U[2024-06-15 10:00:00Z]
      t2 = ~U[2024-06-15 20:00:00Z]

      Collector.track_error(%{type: :timeout, endpoint: "/sendMessage", timestamp: t1})
      Collector.track_error(%{type: :timeout, endpoint: "/sendMessage", timestamp: t2})

      :timer.sleep(20)

      params = %{
        time_range: %{
          start: "2024-06-15T09:00:00Z",
          end: "2024-06-15T12:00:00Z"
        }
      }

      assert {:ok, result} = ErrorMonitoring.handler(params, @agent_ctx)
      assert result.total_errors == 1
    end

    test "filters by error type" do
      now = DateTime.utc_now()

      Collector.track_error(%{type: :timeout, endpoint: "/sendMessage", timestamp: now})
      Collector.track_error(%{type: :rate_limit, endpoint: "/sendMessage", timestamp: now})

      :timer.sleep(20)

      assert {:ok, result} = ErrorMonitoring.handler(%{error_type: "timeout"}, @agent_ctx)
      assert result.total_errors == 1
      assert result.errors_by_type[:timeout] == 1
    end

    test "calculates error rate" do
      now = DateTime.utc_now()

      for _ <- 1..5 do
        Collector.track_error(%{type: :timeout, endpoint: "/sendMessage", timestamp: now})
      end

      :timer.sleep(20)

      assert {:ok, result} = ErrorMonitoring.handler(%{}, @agent_ctx)
      assert is_number(result.error_rate)
    end

    test "reports error trend direction" do
      now = DateTime.utc_now()

      Collector.track_error(%{type: :timeout, endpoint: "/send", timestamp: now})

      :timer.sleep(20)

      assert {:ok, result} = ErrorMonitoring.handler(%{}, @agent_ctx)
      assert result.error_trend in ["increasing", "decreasing", "stable"]
    end
  end
end
