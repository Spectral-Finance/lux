defmodule Lux.Prisms.Telegram.Analytics.MessageAnalyticsTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Integrations.Telegram.Analytics.Collector
  alias Lux.Prisms.Telegram.Analytics.MessageAnalytics

  @agent_ctx %{name: "TestAgent"}

  setup do
    name = Collector
    {:ok, pid} = Collector.start_link(name: name)

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    %{server: name}
  end

  describe "handler/2" do
    test "returns message analytics with no data" do
      assert {:ok, result} = MessageAnalytics.handler(%{}, @agent_ctx)

      assert result.total_messages == 0
      assert result.messages_by_type == %{}
      assert result.messages_per_hour == 0.0
      assert result.peak_hours == []
    end

    test "returns correct totals and type breakdown" do
      now = DateTime.utc_now()

      Collector.track_message(%{type: :text, chat_id: 1, timestamp: now})
      Collector.track_message(%{type: :text, chat_id: 2, timestamp: now})
      Collector.track_message(%{type: :photo, chat_id: 1, timestamp: now})
      Collector.track_message(%{type: :video, chat_id: 3, timestamp: now})

      :timer.sleep(20)

      assert {:ok, result} = MessageAnalytics.handler(%{}, @agent_ctx)

      assert result.total_messages == 4
      assert result.messages_by_type[:text] == 2
      assert result.messages_by_type[:photo] == 1
      assert result.messages_by_type[:video] == 1
    end

    test "filters by chat_id" do
      now = DateTime.utc_now()

      Collector.track_message(%{type: :text, chat_id: 100, timestamp: now})
      Collector.track_message(%{type: :text, chat_id: 200, timestamp: now})
      Collector.track_message(%{type: :photo, chat_id: 100, timestamp: now})

      :timer.sleep(20)

      assert {:ok, result} = MessageAnalytics.handler(%{chat_id: 100}, @agent_ctx)

      assert result.total_messages == 2
    end

    test "filters by time range" do
      t1 = ~U[2024-06-15 10:00:00Z]
      t2 = ~U[2024-06-15 14:00:00Z]
      t3 = ~U[2024-06-15 20:00:00Z]

      Collector.track_message(%{type: :text, chat_id: 1, timestamp: t1})
      Collector.track_message(%{type: :text, chat_id: 2, timestamp: t2})
      Collector.track_message(%{type: :text, chat_id: 3, timestamp: t3})

      :timer.sleep(20)

      params = %{
        time_range: %{
          start: "2024-06-15T09:00:00Z",
          end: "2024-06-15T15:00:00Z"
        }
      }

      assert {:ok, result} = MessageAnalytics.handler(params, @agent_ctx)
      assert result.total_messages == 2
    end

    test "returns peak hours data" do
      now = DateTime.utc_now()

      for _ <- 1..5 do
        Collector.track_message(%{type: :text, chat_id: 1, timestamp: now})
      end

      :timer.sleep(20)

      assert {:ok, result} = MessageAnalytics.handler(%{}, @agent_ctx)
      assert length(result.peak_hours) >= 1
      assert hd(result.peak_hours).message_count == 5
    end
  end
end
