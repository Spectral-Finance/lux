defmodule Lux.Integrations.Telegram.Analytics.CollectorTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Integrations.Telegram.Analytics.Collector

  setup do
    # Start a fresh collector for each test with a unique name
    name = :"collector_#{:erlang.unique_integer([:positive])}"
    {:ok, pid} = Collector.start_link(name: name, retention_period: :timer.hours(1))

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    %{server: name}
  end

  describe "start_link/1" do
    test "starts the collector GenServer" do
      name = :"collector_start_test_#{:erlang.unique_integer([:positive])}"
      assert {:ok, pid} = Collector.start_link(name: name)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "accepts custom retention period" do
      name = :"collector_retention_#{:erlang.unique_integer([:positive])}"
      assert {:ok, pid} = Collector.start_link(name: name, retention_period: :timer.hours(12))
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "track_message/2" do
    test "records a message event", %{server: server} do
      event = %{type: :text, chat_id: 123, timestamp: DateTime.utc_now()}
      assert :ok = Collector.track_message(event, server)

      # Give the cast time to process
      :timer.sleep(10)

      stats = Collector.get_stats(server)
      assert length(stats.messages) == 1
      assert hd(stats.messages).type == :text
      assert hd(stats.messages).chat_id == 123
    end

    test "records multiple message types", %{server: server} do
      now = DateTime.utc_now()

      Collector.track_message(%{type: :text, chat_id: 1, timestamp: now}, server)
      Collector.track_message(%{type: :photo, chat_id: 2, timestamp: now}, server)
      Collector.track_message(%{type: :video, chat_id: 3, timestamp: now}, server)

      :timer.sleep(10)

      stats = Collector.get_stats(server)
      assert length(stats.messages) == 3

      types = Enum.map(stats.messages, & &1.type) |> Enum.sort()
      assert types == [:photo, :text, :video]
    end
  end

  describe "track_command/2" do
    test "records a command event", %{server: server} do
      event = %{name: "/start", user_id: 456, timestamp: DateTime.utc_now()}
      assert :ok = Collector.track_command(event, server)

      :timer.sleep(10)

      stats = Collector.get_stats(server)
      assert length(stats.commands) == 1
      assert hd(stats.commands).name == "/start"
    end

    test "records multiple commands", %{server: server} do
      now = DateTime.utc_now()

      Collector.track_command(%{name: "/start", user_id: 1, timestamp: now}, server)
      Collector.track_command(%{name: "/help", user_id: 2, timestamp: now}, server)
      Collector.track_command(%{name: "/start", user_id: 3, timestamp: now}, server)

      :timer.sleep(10)

      stats = Collector.get_stats(server)
      assert length(stats.commands) == 3
    end
  end

  describe "track_error/2" do
    test "records an error event", %{server: server} do
      event = %{type: :timeout, endpoint: "/sendMessage", timestamp: DateTime.utc_now()}
      assert :ok = Collector.track_error(event, server)

      :timer.sleep(10)

      stats = Collector.get_stats(server)
      assert length(stats.errors) == 1
      assert hd(stats.errors).type == :timeout
      assert hd(stats.errors).endpoint == "/sendMessage"
    end
  end

  describe "track_response_time/3" do
    test "records a response time measurement", %{server: server} do
      assert :ok = Collector.track_response_time("/sendMessage", 150, server)

      :timer.sleep(10)

      stats = Collector.get_stats(server)
      assert length(stats.response_times) == 1
      assert hd(stats.response_times).endpoint == "/sendMessage"
      assert hd(stats.response_times).duration_ms == 150
    end

    test "records multiple response times", %{server: server} do
      Collector.track_response_time("/sendMessage", 100, server)
      Collector.track_response_time("/sendMessage", 200, server)
      Collector.track_response_time("/getUpdates", 50, server)

      :timer.sleep(10)

      stats = Collector.get_stats(server)
      assert length(stats.response_times) == 3
    end
  end

  describe "track_custom_metric/4" do
    test "records a custom metric", %{server: server} do
      assert :ok = Collector.track_custom_metric("api_latency", 120.5, %{region: "us-east"}, server)

      :timer.sleep(10)

      stats = Collector.get_stats(server)
      assert length(stats.custom_metrics) == 1

      metric = hd(stats.custom_metrics)
      assert metric.metric_name == "api_latency"
      assert metric.metric_value == 120.5
      assert metric.tags == %{region: "us-east"}
      assert is_binary(metric.metric_id)
    end
  end

  describe "get_stats/1" do
    test "returns empty stats when no data collected", %{server: server} do
      stats = Collector.get_stats(server)

      assert stats.messages == []
      assert stats.commands == []
      assert stats.errors == []
      assert stats.response_times == []
      assert stats.custom_metrics == []
    end

    test "returns all collected data", %{server: server} do
      now = DateTime.utc_now()

      Collector.track_message(%{type: :text, chat_id: 1, timestamp: now}, server)
      Collector.track_command(%{name: "/start", user_id: 1, timestamp: now}, server)
      Collector.track_error(%{type: :timeout, endpoint: "/send", timestamp: now}, server)
      Collector.track_response_time("/send", 100, server)
      Collector.track_custom_metric("test", 42, %{}, server)

      :timer.sleep(10)

      stats = Collector.get_stats(server)
      assert length(stats.messages) == 1
      assert length(stats.commands) == 1
      assert length(stats.errors) == 1
      assert length(stats.response_times) == 1
      assert length(stats.custom_metrics) == 1
    end
  end

  describe "reset/1" do
    test "clears all collected data", %{server: server} do
      now = DateTime.utc_now()

      Collector.track_message(%{type: :text, chat_id: 1, timestamp: now}, server)
      Collector.track_command(%{name: "/start", user_id: 1, timestamp: now}, server)
      Collector.track_error(%{type: :timeout, endpoint: "/send", timestamp: now}, server)

      :timer.sleep(10)

      assert :ok = Collector.reset(server)

      stats = Collector.get_stats(server)
      assert stats.messages == []
      assert stats.commands == []
      assert stats.errors == []
      assert stats.response_times == []
      assert stats.custom_metrics == []
    end
  end

  describe "automatic pruning" do
    test "prune message is handled without crashing", %{server: server} do
      # Send the prune message directly
      send(GenServer.whereis(server), :prune)
      :timer.sleep(10)

      # Server should still be alive and functional
      stats = Collector.get_stats(server)
      assert is_map(stats)
    end
  end
end
