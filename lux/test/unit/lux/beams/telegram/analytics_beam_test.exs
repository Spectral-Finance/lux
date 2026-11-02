defmodule Lux.Beams.Telegram.AnalyticsBeamTest do
  use ExUnit.Case, async: true

  alias Lux.Beams.Telegram.AnalyticsBeam

  describe "AnalyticsBeam" do
    test "processes events through full analytics pipeline and generates report" do
      t = DateTime.utc_now()

      events = [
        %{
          type: :message,
          chat_type: "supergroup",
          timestamp: t,
          user_id: 10,
          chat_id: -100,
          metadata: %{message_type: :text}
        },
        %{
          type: :command,
          command: "swap",
          status: :success,
          latency_ms: 120,
          chat_type: "private",
          timestamp: t,
          user_id: 10,
          chat_id: 10
        },
        %{
          type: :command,
          command: "help",
          status: :success,
          latency_ms: 60,
          chat_type: "private",
          timestamp: t,
          user_id: 20,
          chat_id: 20
        }
      ]

      assert {:ok, result} = AnalyticsBeam.analyze_events(events, format: "markdown")

      assert result.metrics.messages.total_messages == 3
      assert result.metrics.engagement.unique_active_users == 2
      assert result.metrics.commands.total_command_invocations == 2
      assert result.performance.error_rate_percent == 0.0
      assert result.performance.latency.p50 == 90
      assert is_integer(result.patterns.peak_hour_utc)
      assert String.contains?(result.report.report, "Telegram Bot Analytics")
    end
  end
end
