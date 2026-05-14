defmodule Lux.Integrations.Telegram.AnalyticsTest do
  use UnitCase, async: true

  alias Lux.Integrations.Telegram.Analytics

  describe "normalize_event/1" do
    test "normalizes Telegram messages and extracts commands" do
      event =
        Analytics.normalize_event(%{
          "update_id" => 1,
          "message" => %{
            "message_id" => 10,
            "date" => 1_700_000_000,
            "text" => "/start now",
            "chat" => %{"id" => -100, "type" => "supergroup"},
            "from" => %{"id" => 42, "username" => "alice"}
          },
          "latency_ms" => 120
        })

      assert event.type == :command
      assert event.command == "start"
      assert event.chat_id == -100
      assert event.user_id == 42
      assert event.latency_ms == 120
      assert event.timestamp == "2023-11-14T22:13:20Z"
    end

    test "normalizes callback queries and failed operations" do
      callback =
        Analytics.normalize_event(%{
          callback_query: %{
            data: "approve",
            from: %{id: 7},
            message: %{message_id: 5, chat: %{id: 9}}
          }
        })

      error = Analytics.normalize_event(%{ok: false, error: "timeout", latency_ms: "1500"})

      assert callback.type == :callback_query
      assert callback.callback_data == "approve"
      assert error.type == :error
      assert error.error == "timeout"
      assert error.latency_ms == 1500
    end
  end

  describe "report/2" do
    test "builds usage, command, error, performance, and retention summaries" do
      report =
        Analytics.report(sample_updates(),
          previous_user_ids: [42, 100],
          custom_metrics: [%{name: "group_events", field: :chat_id, value: -1}],
          generated_at: "2026-05-14T00:00:00Z"
        )

      assert report.generated_at == "2026-05-14T00:00:00Z"
      assert report.totals.total_updates == 6
      assert report.totals.messages == 3
      assert report.totals.commands == 1
      assert report.totals.errors == 1
      assert report.engagement.active_chats == 2
      assert report.engagement.active_users == 4
      assert report.commands.top_commands == [%{value: "start", count: 1}]
      assert report.errors.error_rate == 0.1667
      assert report.errors.by_reason == %{"timeout" => 1}
      assert report.performance.p95_latency_ms == 1_500
      assert report.retention.retained_users == 1
      assert report.retention.new_users == 3

      assert report.custom_metrics == [
               %{name: "group_events", field: :chat_id, value: -1, count: 3}
             ]

      assert [%{"type" => :callback_query, "count" => 1} | _] =
               report.visualizations.event_type_bar
    end

    test "returns empty safe defaults" do
      report = Analytics.report([])

      assert report.totals.total_updates == 0
      assert report.errors.error_rate == 0.0
      assert report.performance.samples == 0
      assert report.performance.p95_latency_ms == nil
      assert report.retention.retention_rate == 0.0
      assert report.custom_metrics == []
    end

    test "treats ok false as an error even without an error reason" do
      report = Analytics.report([%{"ok" => false}])

      assert report.totals.errors == 1
      assert report.errors.by_reason == %{"unknown" => 1}
    end
  end

  describe "alerts/2" do
    test "returns danger when error rate or latency crosses danger thresholds" do
      report = Analytics.report(sample_updates())

      alert_payload =
        Analytics.alerts(report, %{
          "error_rate_danger" => 0.10,
          "p95_latency_danger_ms" => 1_000,
          :error_rate_warning => 0.05,
          :p95_latency_warning_ms => 500
        })

      assert alert_payload.severity == :danger
      assert Enum.any?(alert_payload.alerts, &(&1.metric == :error_rate))
      assert Enum.any?(alert_payload.alerts, &(&1.metric == :p95_latency_ms))
    end
  end

  describe "report_payload/2" do
    test "builds a compact dashboard payload" do
      report = Analytics.report(sample_updates())
      payload = Analytics.report_payload(report, title: "Ops report")

      assert payload.title == "Ops report"
      assert payload.summary.total_updates == 6

      assert Enum.map(payload.sections, & &1.name) == [
               "Usage",
               "Commands",
               "Errors",
               "Performance",
               "Retention",
               "Custom Metrics"
             ]

      assert Map.has_key?(payload.visualizations, :hourly_volume_series)
    end
  end

  defp sample_updates do
    [
      %{
        update_id: 1,
        message: %{
          message_id: 1,
          date: 1_700_000_000,
          text: "/start",
          chat: %{id: -1, type: "group"},
          from: %{id: 42, username: "alice"}
        },
        latency_ms: 100
      },
      %{
        update_id: 2,
        message: %{
          message_id: 2,
          date: 1_700_003_600,
          text: "hello",
          chat: %{id: -1, type: "group"},
          from: %{id: 43}
        },
        latency_ms: 180
      },
      %{
        update_id: 3,
        callback_query: %{
          data: "refresh",
          from: %{id: 44},
          message: %{message_id: 3, chat: %{id: -1}}
        },
        latency_ms: 250
      },
      %{
        update_id: 4,
        chat_member: %{
          date: 1_700_007_200,
          chat: %{id: -2},
          from: %{id: 45},
          old_chat_member: %{status: "left"},
          new_chat_member: %{status: "member"}
        }
      },
      %{
        type: :message,
        chat_id: -2,
        user_id: 45,
        text: "manual event",
        timestamp: "2023-11-15T00:00:00Z"
      },
      %{ok: false, error: "timeout", latency_ms: 1_500, timestamp: "2023-11-15T00:00:00Z"}
    ]
  end
end
