defmodule Lux.Lenses.Telegram.BotMetricsTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Integrations.Telegram.Analytics.Collector
  alias Lux.Lenses.Telegram.BotMetrics

  setup do
    {:ok, pid} = Collector.start_link(name: Collector)

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    :ok
  end

  describe "get_metrics/1" do
    test "returns summary format by default" do
      now = DateTime.utc_now()

      Collector.track_message(%{type: :text, chat_id: 1, timestamp: now})
      Collector.track_command(%{name: "/start", user_id: 1, timestamp: now})

      :timer.sleep(20)

      assert {:ok, result} = BotMetrics.get_metrics()

      assert is_map(result)
      assert Map.has_key?(result, :messages)
      assert Map.has_key?(result, :commands)
      assert Map.has_key?(result, :errors)
      assert Map.has_key?(result, :performance)
      assert result.messages.total == 1
      assert result.commands.total == 1
    end

    test "returns JSON format" do
      now = DateTime.utc_now()

      Collector.track_message(%{type: :text, chat_id: 1, timestamp: now})

      :timer.sleep(20)

      assert {:ok, result} = BotMetrics.get_metrics(:json)

      assert is_map(result)
      assert Map.has_key?(result, "messages")
      assert result["messages"]["total"] == 1
    end

    test "returns ASCII format" do
      now = DateTime.utc_now()

      Collector.track_message(%{type: :text, chat_id: 1, timestamp: now})

      :timer.sleep(20)

      assert {:ok, result} = BotMetrics.get_metrics(:ascii)

      assert is_binary(result)
      assert String.contains?(result, "Telegram Bot Analytics Report")
    end

    test "works with empty data" do
      assert {:ok, result} = BotMetrics.get_metrics()

      assert result.messages.total == 0
      assert result.commands.total == 0
      assert result.errors.total == 0
    end

    test "includes performance metrics" do
      Collector.track_response_time("/sendMessage", 100)
      Collector.track_response_time("/sendMessage", 200)

      :timer.sleep(20)

      assert {:ok, result} = BotMetrics.get_metrics()

      assert result.performance.avg_response_time == 150.0
      assert result.performance.min == 100
      assert result.performance.max == 200
    end

    test "includes error metrics" do
      now = DateTime.utc_now()

      Collector.track_error(%{type: :timeout, endpoint: "/sendMessage", timestamp: now})
      Collector.track_error(%{type: :rate_limit, endpoint: "/sendMessage", timestamp: now})

      :timer.sleep(20)

      assert {:ok, result} = BotMetrics.get_metrics()

      assert result.errors.total == 2
      assert result.errors.by_type[:timeout] == 1
      assert result.errors.by_type[:rate_limit] == 1
    end
  end

  describe "after_focus/1" do
    test "returns metrics summary" do
      now = DateTime.utc_now()

      Collector.track_message(%{type: :text, chat_id: 1, timestamp: now})

      :timer.sleep(20)

      assert {:ok, result} = BotMetrics.after_focus(%{})

      assert is_map(result)
      assert Map.has_key?(result, :messages)
    end
  end
end
