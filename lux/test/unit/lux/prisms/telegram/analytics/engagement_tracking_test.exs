defmodule Lux.Prisms.Telegram.Analytics.EngagementTrackingTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Integrations.Telegram.Analytics.Collector
  alias Lux.Prisms.Telegram.Analytics.EngagementTracking

  @agent_ctx %{name: "TestAgent"}

  setup do
    {:ok, pid} = Collector.start_link(name: Collector)

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    :ok
  end

  describe "handler/2" do
    test "returns engagement metrics with no data" do
      assert {:ok, result} = EngagementTracking.handler(%{}, @agent_ctx)

      assert result.unique_users == 0
      assert result.active_users == 0
      assert result.messages_per_user == 0.0
      assert result.top_users == []
      assert result.retention_rate == 0.0
    end

    test "counts unique users from messages" do
      now = DateTime.utc_now()

      Collector.track_message(%{type: :text, chat_id: 100, timestamp: now})
      Collector.track_message(%{type: :text, chat_id: 200, timestamp: now})
      Collector.track_message(%{type: :text, chat_id: 100, timestamp: now})

      :timer.sleep(20)

      assert {:ok, result} = EngagementTracking.handler(%{}, @agent_ctx)

      assert result.unique_users == 2
    end

    test "identifies active users with 2+ interactions" do
      now = DateTime.utc_now()

      # User 100 has 3 interactions - active
      Collector.track_message(%{type: :text, chat_id: 100, timestamp: now})
      Collector.track_message(%{type: :text, chat_id: 100, timestamp: now})
      Collector.track_message(%{type: :text, chat_id: 100, timestamp: now})
      # User 200 has 1 interaction - not active
      Collector.track_message(%{type: :text, chat_id: 200, timestamp: now})

      :timer.sleep(20)

      assert {:ok, result} = EngagementTracking.handler(%{}, @agent_ctx)

      assert result.active_users == 1
    end

    test "calculates messages per user" do
      now = DateTime.utc_now()

      Collector.track_message(%{type: :text, chat_id: 100, timestamp: now})
      Collector.track_message(%{type: :text, chat_id: 200, timestamp: now})
      Collector.track_message(%{type: :text, chat_id: 100, timestamp: now})
      Collector.track_message(%{type: :text, chat_id: 200, timestamp: now})

      :timer.sleep(20)

      assert {:ok, result} = EngagementTracking.handler(%{}, @agent_ctx)

      assert result.messages_per_user == 2.0
    end

    test "returns top users sorted by activity" do
      now = DateTime.utc_now()

      for _ <- 1..5, do: Collector.track_message(%{type: :text, chat_id: 100, timestamp: now})
      for _ <- 1..3, do: Collector.track_message(%{type: :text, chat_id: 200, timestamp: now})
      Collector.track_message(%{type: :text, chat_id: 300, timestamp: now})

      :timer.sleep(20)

      assert {:ok, result} = EngagementTracking.handler(%{}, @agent_ctx)

      assert hd(result.top_users).user_id == 100
      assert hd(result.top_users).message_count == 5
    end

    test "calculates retention rate" do
      now = DateTime.utc_now()

      # 2 out of 3 users are active (2+ interactions)
      Collector.track_message(%{type: :text, chat_id: 100, timestamp: now})
      Collector.track_message(%{type: :text, chat_id: 100, timestamp: now})
      Collector.track_message(%{type: :text, chat_id: 200, timestamp: now})
      Collector.track_message(%{type: :text, chat_id: 200, timestamp: now})
      Collector.track_message(%{type: :text, chat_id: 300, timestamp: now})

      :timer.sleep(20)

      assert {:ok, result} = EngagementTracking.handler(%{}, @agent_ctx)

      assert_in_delta result.retention_rate, 66.67, 0.1
    end

    test "includes command events in engagement" do
      now = DateTime.utc_now()

      Collector.track_command(%{name: "/start", user_id: 100, timestamp: now})
      Collector.track_command(%{name: "/help", user_id: 100, timestamp: now})

      :timer.sleep(20)

      assert {:ok, result} = EngagementTracking.handler(%{}, @agent_ctx)

      assert result.unique_users == 1
      assert result.active_users == 1
    end
  end
end
