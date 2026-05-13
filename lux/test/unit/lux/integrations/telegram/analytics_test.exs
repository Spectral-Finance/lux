defmodule Lux.Integrations.Telegram.AnalyticsTest do
  use UnitCase, async: true

  alias Lux.Integrations.Telegram.Analytics

  @message_update %{
    "update_id" => 1,
    "message" => %{
      "message_id" => 10,
      "date" => 1_800,
      "text" => "/start hello",
      "from" => %{"id" => 101, "username" => "ada"},
      "chat" => %{"id" => -100, "type" => "supergroup"}
    }
  }

  @photo_update %{
    update_id: 2,
    message: %{
      message_id: 11,
      date: 1_820,
      caption: "launch",
      photo: [%{file_id: "a"}],
      from: %{id: 102, username: "grace"},
      chat: %{id: -100, type: "supergroup"}
    }
  }

  @callback_update %{
    update_id: 3,
    callback_query: %{
      id: "cb-1",
      data: "approve",
      from: %{id: 101, username: "ada"},
      message: %{
        message_id: 12,
        date: 1_860,
        chat: %{id: -100, type: "supergroup"}
      }
    }
  }

  describe "event/1" do
    test "normalizes Telegram message updates" do
      event = Analytics.event(@message_update)

      assert event.kind == :message
      assert event.chat_id == -100
      assert event.user_id == 101
      assert event.username == "ada"
      assert event.message_type == :text
      assert event.command == "start"
      assert event.text_length == 12
      assert event.timestamp == 1_800
    end

    test "normalizes media and callback updates" do
      photo = Analytics.event(@photo_update)
      assert photo.message_type == :photo
      assert photo.has_media? == true
      assert photo.text_length == 6

      callback = Analytics.event(@callback_update)
      assert callback.kind == :callback_query
      assert callback.chat_id == -100
      assert callback.user_id == 101
      assert callback.text_length == 7
    end
  end

  describe "summary/1" do
    test "aggregates update activity" do
      summary = Analytics.summary([@message_update, @photo_update, @callback_update])

      assert summary.total_updates == 3
      assert summary.active_chats == 1
      assert summary.active_users == 2
      assert summary.messages == 2
      assert summary.callback_queries == 1
      assert summary.commands == 1
      assert summary.media_messages == 1
      assert summary.by_chat[-100] == 3
      assert summary.by_command["start"] == 1
      assert summary.by_type.photo == 1
    end
  end

  describe "buckets/2 and alerts/2" do
    test "builds rolling buckets and monitoring alerts" do
      buckets = Analytics.buckets([@message_update, @photo_update, @callback_update], 60)

      assert Enum.map(buckets, & &1.window_start) == [1_800, 1_860]
      assert hd(buckets).total_updates == 2

      alerts =
        [@message_update, @photo_update, @callback_update]
        |> Analytics.summary()
        |> Analytics.alerts(%{
          max_updates: 2,
          max_callback_queries: 0,
          min_active_users: 3,
          max_commands: 0
        })

      assert Enum.map(alerts, & &1.reason) == [
               :update_volume_high,
               :callback_volume_high,
               :active_users_low,
               :command_volume_high
             ]
    end
  end

  describe "report/2" do
    test "builds serializable report payloads" do
      report =
        Analytics.report([@message_update, @photo_update, @callback_update], %{
          chat_id: -100,
          generated_at: "2026-05-13T04:30:00Z",
          thresholds: %{max_updates: 2},
          limit: 1
        })

      assert report.chat_id == -100
      assert report.generated_at == "2026-05-13T04:30:00Z"
      assert report.summary.total_updates == 3
      assert [%{key: -100, count: 3}] = report.top_chats
      assert [%{reason: :update_volume_high}] = report.alerts
    end
  end

  describe "retention/1" do
    test "calculates retained users between first and latest periods" do
      retention =
        Analytics.retention([
          %{period: "2026-05-11", users: [1, 2, 3]},
          %{period: "2026-05-12", users: [2, 3, 4]},
          %{period: "2026-05-13", users: [3, 4, 5]}
        ])

      assert retention.period_count == 3
      assert retention.retained_users == 1
      assert_in_delta retention.retention_rate, 0.3333, 0.0001
    end
  end
end
