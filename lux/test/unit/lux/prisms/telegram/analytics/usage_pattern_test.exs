defmodule Lux.Prisms.Telegram.Analytics.UsagePatternTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Integrations.Telegram.Analytics.Collector
  alias Lux.Prisms.Telegram.Analytics.UsagePattern

  @agent_ctx %{name: "TestAgent"}

  setup do
    {:ok, pid} = Collector.start_link(name: Collector)

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    :ok
  end

  describe "handler/2" do
    test "returns usage patterns with no data" do
      assert {:ok, result} = UsagePattern.handler(%{}, @agent_ctx)

      assert result.peak_hours == []
      assert result.quiet_hours == []
      assert result.busiest_days == []
      assert result.usage_trend == "stable"
      assert result.anomalies == []
    end

    test "identifies peak and quiet hours" do
      # Simulate events at different hours
      for hour <- [10, 10, 10, 14, 14, 18] do
        {:ok, dt} = DateTime.new(~D[2024-06-15], Time.new!(hour, 0, 0), "Etc/UTC")
        Collector.track_message(%{type: :text, chat_id: 1, timestamp: dt})
      end

      :timer.sleep(20)

      assert {:ok, result} = UsagePattern.handler(%{}, @agent_ctx)

      assert length(result.peak_hours) > 0
      assert 10 in result.peak_hours
    end

    test "identifies busiest days" do
      for _ <- 1..5 do
        Collector.track_message(%{type: :text, chat_id: 1, timestamp: ~U[2024-06-15 10:00:00Z]})
      end

      for _ <- 1..2 do
        Collector.track_message(%{type: :text, chat_id: 1, timestamp: ~U[2024-06-16 10:00:00Z]})
      end

      :timer.sleep(20)

      assert {:ok, result} = UsagePattern.handler(%{}, @agent_ctx)

      assert length(result.busiest_days) >= 1
      assert hd(result.busiest_days).date == "2024-06-15"
      assert hd(result.busiest_days).count == 5
    end

    test "reports usage trend" do
      now = DateTime.utc_now()

      Collector.track_message(%{type: :text, chat_id: 1, timestamp: now})

      :timer.sleep(20)

      assert {:ok, result} = UsagePattern.handler(%{}, @agent_ctx)
      assert result.usage_trend in ["increasing", "decreasing", "stable"]
    end

    test "accepts granularity parameter" do
      now = DateTime.utc_now()
      Collector.track_message(%{type: :text, chat_id: 1, timestamp: now})
      :timer.sleep(20)

      assert {:ok, _result} = UsagePattern.handler(%{granularity: "daily"}, @agent_ctx)
      assert {:ok, _result} = UsagePattern.handler(%{granularity: "hourly"}, @agent_ctx)
    end

    test "includes both message and command events" do
      now = DateTime.utc_now()

      Collector.track_message(%{type: :text, chat_id: 1, timestamp: now})
      Collector.track_command(%{name: "/start", user_id: 1, timestamp: now})

      :timer.sleep(20)

      assert {:ok, result} = UsagePattern.handler(%{}, @agent_ctx)

      # Both events should contribute to the pattern analysis
      assert length(result.peak_hours) > 0
    end
  end
end
