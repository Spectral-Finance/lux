defmodule Lux.Lenses.Telegram.Analytics.ChatMetricsTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Telegram.Analytics.ChatMetrics

  describe "before_focus/1" do
    test "constructs correct URL with bot token" do
      params = %{chat_id: "-1001234567890"}
      result = ChatMetrics.before_focus(params)

      assert Map.get(result, :chat_id) == "-1001234567890"
      assert Map.has_key?(result, :url)
    end
  end

  describe "after_focus/1" do
    test "parses successful member count response" do
      body = %{"ok" => true, "result" => 5000}

      {:ok, result} = ChatMetrics.after_focus(body)

      assert result.member_count == 5000
      assert Map.has_key?(result, :retrieved_at)
    end

    test "handles error response" do
      body = %{"ok" => false, "description" => "Bad Request: chat not found"}

      {:error, reason} = ChatMetrics.after_focus(body)
      assert reason =~ "chat not found"
    end
  end
end

defmodule Lux.Lenses.Telegram.Analytics.ChannelStatsTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Telegram.Analytics.ChannelStats

  describe "after_focus/1" do
    test "parses channel statistics response" do
      body = %{
        "ok" => true,
        "result" => %{
          "member_count" => 12000,
          "message_count" => 50000,
          "view_count" => 100000,
          "growth" => %{
            "member_count" => [
              %{"date" => "2024-01-01", "value" => 11900},
              %{"date" => "2024-01-02", "value" => 12000}
            ]
          },
          "interactions" => %{
            "day" => [%{"date" => "2024-01-01", "count" => 500}]
          }
        }
      }

      {:ok, result} = ChannelStats.after_focus(body)

      assert result.statistics.member_count == 12000
      assert length(result.statistics.growth.member_count) == 2
    end

    test "handles error response" do
      body = %{"ok" => false, "error_code" => 400, "description" => "Bad Request"}

      {:error, reason} = ChannelStats.after_focus(body)
      assert reason =~ "400"
    end
  end
end

defmodule Lux.Lenses.Telegram.Analytics.MessageAnalyticsTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Telegram.Analytics.MessageAnalytics

  describe "before_focus/1" do
    test "sets default limit to 100" do
      params = %{chat_id: "-1001234567890"}
      result = MessageAnalytics.before_focus(params)

      assert Map.get(result, :limit) == 100
    end

    test "preserves explicit limit" do
      params = %{chat_id: "-1001234567890", limit: 500}
      result = MessageAnalytics.before_focus(params)

      assert Map.get(result, :limit) == 500
    end
  end

  describe "after_focus/1" do
    test "computes analytics from message list" do
      body = %{
        "ok" => true,
        "result" => [
          %{"from" => %{"id" => 1}, "text" => "Hello world", "date" => 1704067200},
          %{"from" => %{"id" => 2}, "text" => "Hi there", "date" => 1704067260},
          %{"from" => %{"id" => 1}, "photo" => [%{}], "date" => 1704067320}
        ]
      }

      {:ok, result} = MessageAnalytics.after_focus(body)

      assert result.analytics.total_messages == 3
      assert result.analytics.active_users == 2
      assert result.analytics.message_types["text"] == 2
      assert result.analytics.message_types["photo"] == 1
    end
  end
end
