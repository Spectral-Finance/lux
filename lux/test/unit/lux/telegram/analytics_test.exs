defmodule Lux.Telegram.AnalyticsTest do
  use UnitCase, async: true

  alias Lux.Telegram.Analytics
  alias Lux.Prisms.Telegram.Analytics.CollectUpdateMetrics
  alias Lux.Prisms.Telegram.Analytics.ErrorRateMonitor
  alias Lux.Prisms.Telegram.Analytics.UsageReport

  describe "collect_update/2" do
    test "normalizes message updates and extracts commands" do
      event =
        Analytics.collect_update(%{
          "update_id" => 42,
          "message" => %{
            "message_id" => 7,
            "text" => "/start hello",
            "chat" => %{"id" => -100},
            "from" => %{"id" => 123}
          }
        })

      assert event.update_id == 42
      assert event.kind == :message
      assert event.command == "/start"
      assert event.chat_id == -100
      assert event.user_id == 123
      assert event.text_length == 12
    end

    test "normalizes callback query updates" do
      event =
        Analytics.collect_update(%{
          update_id: 43,
          callback_query: %{
            data: "approve:1",
            from: %{id: 321}
          }
        })

      assert event.kind == :callback_query
      assert event.user_id == 321
      assert event.text_length == 9
    end
  end

  describe "aggregate/1" do
    test "computes usage, performance, and visualization metrics" do
      events = [
        Analytics.collect_update(message_update("/start", 1, 10), latency_ms: 20),
        Analytics.collect_update(message_update("/help", 1, 10), latency_ms: 40),
        Analytics.collect_update(message_update("plain text", 2, 11), error: "timeout")
      ]

      metrics = Analytics.aggregate(events)

      assert metrics.total_updates == 3
      assert metrics.messages == 3
      assert metrics.unique_users == 2
      assert metrics.unique_chats == 2
      assert metrics.commands == %{"/start" => 1, "/help" => 1}
      assert metrics.errors == 1
      assert_in_delta metrics.error_rate, 0.333, 0.001
      assert metrics.avg_latency_ms == 30.0
      assert metrics.p95_latency_ms == 40
      assert metrics.visualization.updates_by_kind == %{message: 3}
    end
  end

  describe "prisms" do
    test "CollectUpdateMetrics returns aggregate metrics" do
      {:ok, metrics} =
        CollectUpdateMetrics.run(%{
          updates: [
            message_update("/start", 1, 10),
            message_update("hello", 2, 10)
          ]
        })

      assert metrics.total_updates == 2
      assert metrics.unique_users == 2
      assert metrics.commands == %{"/start" => 1}
    end

    test "ErrorRateMonitor flags streams above threshold" do
      events = [
        Analytics.collect_update(message_update("ok", 1, 10)),
        Analytics.collect_update(message_update("bad", 2, 10), error: "timeout")
      ]

      {:ok, result} = ErrorRateMonitor.run(%{events: events, threshold: 0.2})

      assert result.status == "alert"
      assert result.errors == 1
      assert result.total_updates == 2
    end

    test "UsageReport includes top commands and visualization data" do
      events = [
        Analytics.collect_update(message_update("/start", 1, 10)),
        Analytics.collect_update(message_update("/start", 2, 10)),
        Analytics.collect_update(message_update("/help", 2, 10))
      ]

      {:ok, report} = UsageReport.run(%{events: events})

      assert report.status == "ok"
      assert report.summary.unique_users == 2
      assert [%{command: "/start", count: 2}, %{command: "/help", count: 1}] = report.top_commands
      assert report.visualization.commands == %{"/start" => 2, "/help" => 1}
    end
  end

  defp message_update(text, user_id, chat_id) do
    %{
      update_id: System.unique_integer([:positive]),
      message: %{
        message_id: System.unique_integer([:positive]),
        text: text,
        from: %{id: user_id},
        chat: %{id: chat_id}
      }
    }
  end
end
