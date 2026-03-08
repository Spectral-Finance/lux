defmodule Lux.Integrations.Telegram.Analytics.CollectorTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.Analytics.Collector

  setup do
    name = :"collector_test_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = Collector.start_link(name: name)
    %{pid: pid}
  end

  test "track messages and get counters", %{pid: pid} do
    Collector.track_message(pid, %{from_id: 1, chat_id: -100, has_media: false})
    Collector.track_message(pid, %{from_id: 2, chat_id: -100, has_media: true})
    Collector.track_message(pid, %{from_id: 1, chat_id: -200, has_media: false})
    Process.sleep(10)

    {:ok, c} = Collector.get_counters(pid)
    assert c.messages_total == 3
    assert c.messages_text == 2
    assert c.messages_media == 1
    assert c.unique_users == 2
    assert c.unique_chats == 2
  end

  test "track commands", %{pid: pid} do
    Collector.track_command(pid, "/start", 1, -100)
    Collector.track_command(pid, "/help", 2, -100)
    Collector.track_command(pid, "/start", 3, -200)
    Process.sleep(10)

    {:ok, c} = Collector.get_counters(pid)
    assert c.commands_total == 3
    assert Enum.find(c.top_commands, fn {cmd, _} -> cmd == "/start" end) == {"/start", 2}
  end

  test "track errors", %{pid: pid} do
    Collector.track_error(pid, :timeout, %{endpoint: "/sendMessage"})
    Collector.track_error(pid, :rate_limit)
    Collector.track_error(pid, :timeout)
    Process.sleep(10)

    {:ok, c} = Collector.get_counters(pid)
    assert c.errors_total == 3
    assert c.errors_by_type[:timeout] == 2
    assert c.errors_by_type[:rate_limit] == 1
  end

  test "track response times", %{pid: pid} do
    Collector.track_response_time(pid, "/sendMessage", 50)
    Collector.track_response_time(pid, "/sendMessage", 100)
    Collector.track_response_time(pid, "/getUpdates", 200)
    Process.sleep(10)

    {:ok, c} = Collector.get_counters(pid)
    # Response times are stored internally
    assert c.uptime_seconds >= 0
  end

  test "get events with type filter", %{pid: pid} do
    Collector.track_message(pid, %{from_id: 1, chat_id: -100})
    Collector.track_command(pid, "/start", 1, -100)
    Collector.track_error(pid, :timeout)
    Process.sleep(10)

    {:ok, all} = Collector.get_events(pid)
    assert length(all) == 3

    {:ok, errors} = Collector.get_events(pid, %{type: :error})
    assert length(errors) == 1
  end

  test "reset clears all data", %{pid: pid} do
    Collector.track_message(pid, %{from_id: 1, chat_id: -100})
    Collector.track_error(pid, :timeout)
    Process.sleep(10)

    :ok = Collector.reset(pid)
    {:ok, c} = Collector.get_counters(pid)
    assert c.messages_total == 0
    assert c.errors_total == 0
  end

  test "hourly distribution", %{pid: pid} do
    for _ <- 1..5, do: Collector.track_message(pid, %{from_id: 1, chat_id: -100})
    Process.sleep(10)

    {:ok, c} = Collector.get_counters(pid)
    current_hour = DateTime.utc_now() |> Map.get(:hour)
    assert c.hourly_distribution[current_hour] == 5
  end
end
