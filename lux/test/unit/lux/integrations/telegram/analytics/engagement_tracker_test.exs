defmodule Lux.Integrations.Telegram.Analytics.EngagementTrackerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.Analytics.EngagementTracker

  describe "EngagementTracker" do
    test "tracks unique active users and computes leaderboards" do
      events = [
        %{user_id: 101, chat_id: -1001},
        %{user_id: 101, chat_id: -1001},
        %{user_id: 101, chat_id: -1002},
        %{user_id: 102, chat_id: -1001},
        %{user_id: 103, chat_id: -1003}
      ]

      result = EngagementTracker.analyze(events)
      assert result.unique_active_users == 3
      assert result.total_interactions == 5
      assert result.average_actions_per_user == 1.67

      top_user = hd(result.top_active_users)
      assert top_user.user_id == 101
      assert top_user.action_count == 3

      top_chat = hd(result.top_active_chats)
      assert top_chat.chat_id == -1001
      assert top_chat.message_count == 3
    end
  end
end
