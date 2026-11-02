defmodule Lux.Integrations.Telegram.Analytics.MessageTrackerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.Analytics.MessageTracker

  describe "MessageTracker" do
    test "analyzes message volumes, distributions, and throughput" do
      t1 = DateTime.utc_now() |> DateTime.add(-3600, :second)
      t2 = DateTime.utc_now()

      events = [
        %{type: :message, chat_type: "supergroup", timestamp: t1, metadata: %{message_type: :text}},
        %{type: :message, chat_type: "supergroup", timestamp: t1, metadata: %{message_type: :photo}},
        %{type: :command, chat_type: "private", timestamp: t2, metadata: %{message_type: :command}},
        %{type: :callback, chat_type: "private", timestamp: t2, metadata: %{}}
      ]

      result = MessageTracker.analyze(events)
      assert result.total_messages == 4
      assert result.chat_distribution["supergroup"] == 2
      assert result.chat_distribution["private"] == 2
      assert result.type_distribution[:text] == 1
      assert result.type_distribution[:photo] == 1
      assert result.messages_per_hour > 0.0
    end
  end
end
