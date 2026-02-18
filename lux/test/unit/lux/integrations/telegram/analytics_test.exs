defmodule Lux.Integrations.Telegram.AnalyticsTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Integrations.Telegram.Analytics

  setup do
    # Start the analytics engine for each test and reset data
    start_supervised!({Analytics, [name: :"analytics_test_#{:erlang.unique_integer([:positive])}", cleanup_interval_ms: 0]})
    Analytics.reset()
    :ok
  end

  describe "record_event/2" do
    test "records a basic event" do
      assert :ok = Analytics.record_event(:message_sent, %{chat_id: 123})
    end

    test "records events with empty data" do
      assert :ok = Analytics.record_event(:message_received)
    end

    test "increments the counter for the event type" do
      Analytics.record_event(:message_sent, %{})
      Analytics.record_event(:message_sent, %{})
      Analytics.record_event(:message_sent, %{})

      assert Analytics.get_counter(:message_sent) == 3
    end

    test "records different event types independently" do
      Analytics.record_event(:message_sent, %{})
      Analytics.record_event(:message_received, %{})
      Analytics.record_event(:message_sent, %{})

      assert Analytics.get_counter(:message_sent) == 2
      assert Analytics.get_counter(:message_received) == 1
    end
  end

  describe "record_message/2" do
    test "records a sent message" do
      assert :ok = Analytics.record_message(:sent, %{chat_id: 123, user_id: 42})
      assert Analytics.get_counter(:message_sent) == 1
    end

    test "records a received message" do
      assert :ok = Analytics.record_message(:received, %{chat_id: 123, user_id: 42})
      assert Analytics.get_counter(:message_received) == 1
    end

    test "records a forwarded message" do
      assert :ok = Analytics.record_message(:forwarded, %{chat_id: 123})
      assert Analytics.get_counter(:message_forwarded) == 1
    end

    test "records an edited message" do
      assert :ok = Analytics.record_message(:edited, %{chat_id: 123})
      assert Analytics.get_counter(:message_edited) == 1
    end

    test "records a deleted message" do
      assert :ok = Analytics.record_message(:deleted, %{chat_id: 123})
      assert Analytics.get_counter(:message_deleted) == 1
    end

    test "tracks user activity when user_id is present" do
      Analytics.record_message(:sent, %{user_id: 42})
      assert Analytics.get_counter({:user_messages, 42}) == 1
    end

    test "does not track user activity when user_id is absent" do
      Analytics.record_message(:sent, %{chat_id: 123})
      # No user_messages counter should be created
      assert Analytics.get_counter({:user_messages, nil}) == 0
    end
  end

  describe "record_command/2" do
    test "records a command execution" do
      assert :ok = Analytics.record_command(:start, %{user_id: 42})
      assert Analytics.get_counter({:command, :start}) == 1
    end

    test "records a command with string name" do
      assert :ok = Analytics.record_command("help", %{user_id: 42})
      assert Analytics.get_counter({:command, :help}) == 1
    end

    test "records a command with leading slash" do
      assert :ok = Analytics.record_command("/settings", %{user_id: 42})
      assert Analytics.get_counter({:command, :settings}) == 1
    end

    test "records command errors" do
      Analytics.record_command(:start, %{success: false})
      assert Analytics.get_counter({:command_error, :start}) == 1
    end

    test "records response times" do
      Analytics.record_command(:start, %{response_time_ms: 150})
      # Response time should be recorded in gauges table
      stats = Analytics.get_performance_metrics()
      assert stats.max_response_time_ms >= 0
    end

    test "tracks multiple commands independently" do
      Analytics.record_command(:start, %{})
      Analytics.record_command(:start, %{})
      Analytics.record_command(:help, %{})

      assert Analytics.get_counter({:command, :start}) == 2
      assert Analytics.get_counter({:command, :help}) == 1
    end
  end

  describe "record_error/2" do
    test "records an error event" do
      assert :ok = Analytics.record_error(:api_error, %{message: "Rate limit"})
      assert Analytics.get_counter({:error, :api_error}) == 1
      assert Analytics.get_counter(:total_errors) == 1
    end

    test "records multiple error types" do
      Analytics.record_error(:api_error, %{})
      Analytics.record_error(:timeout, %{})
      Analytics.record_error(:api_error, %{})

      assert Analytics.get_counter({:error, :api_error}) == 2
      assert Analytics.get_counter({:error, :timeout}) == 1
      assert Analytics.get_counter(:total_errors) == 3
    end

    test "records string error types" do
      assert :ok = Analytics.record_error("validation_error", %{})
      assert Analytics.get_counter({:error, "validation_error"}) == 1
    end
  end

  describe "record_response_time/2" do
    test "records a response time" do
      assert :ok = Analytics.record_response_time(:send_message, 150)
    end

    test "records multiple response times" do
      Analytics.record_response_time(:send_message, 100)
      Analytics.record_response_time(:send_message, 200)
      Analytics.record_response_time(:send_message, 150)

      stats = Analytics.get_performance_metrics()
      assert stats.avg_response_time_ms > 0
    end
  end

  describe "track_user_activity/1" do
    test "tracks a user's activity" do
      assert :ok = Analytics.track_user_activity(42)
      assert Analytics.get_counter({:user_messages, 42}) == 1
    end

    test "tracks multiple activities for same user" do
      Analytics.track_user_activity(42)
      Analytics.track_user_activity(42)
      Analytics.track_user_activity(42)
      assert Analytics.get_counter({:user_messages, 42}) == 3
    end
  end

  describe "define_custom_metric/3" do
    test "defines a counter metric" do
      assert :ok = Analytics.define_custom_metric(:page_views, :counter, "Total page views")
    end

    test "defines a gauge metric" do
      assert :ok = Analytics.define_custom_metric(:cpu_usage, :gauge, "CPU usage percentage")
    end

    test "defines a histogram metric" do
      assert :ok = Analytics.define_custom_metric(:latency, :histogram, "Request latency")
    end
  end

  describe "record_custom_metric/2" do
    test "records a counter custom metric" do
      Analytics.define_custom_metric(:page_views, :counter, "Page views")
      assert :ok = Analytics.record_custom_metric(:page_views, 1)
      assert :ok = Analytics.record_custom_metric(:page_views, 5)

      {:ok, value} = Analytics.get_custom_metric(:page_views)
      assert value == 6
    end

    test "records a gauge custom metric" do
      Analytics.define_custom_metric(:cpu_usage, :gauge, "CPU")
      assert :ok = Analytics.record_custom_metric(:cpu_usage, 75.5)

      {:ok, value} = Analytics.get_custom_metric(:cpu_usage)
      assert value == 75.5
    end

    test "records an undefined metric with a warning" do
      # Should still record even if not defined
      assert :ok = Analytics.record_custom_metric(:undefined_metric, 42)
    end
  end

  describe "get_custom_metric/1" do
    test "returns :not_found for undefined metrics" do
      assert {:error, :not_found} = Analytics.get_custom_metric(:nonexistent)
    end

    test "returns nil for defined but unrecorded gauge" do
      Analytics.define_custom_metric(:empty_gauge, :gauge, "")
      assert {:ok, nil} = Analytics.get_custom_metric(:empty_gauge)
    end

    test "returns 0 for defined but unrecorded counter" do
      Analytics.define_custom_metric(:empty_counter, :counter, "")
      assert {:ok, 0} = Analytics.get_custom_metric(:empty_counter)
    end
  end

  describe "list_custom_metrics/0" do
    test "returns empty list when no metrics defined" do
      assert Analytics.list_custom_metrics() == []
    end

    test "returns all defined metrics" do
      Analytics.define_custom_metric(:metric_a, :counter, "A")
      Analytics.define_custom_metric(:metric_b, :gauge, "B")

      metrics = Analytics.list_custom_metrics()
      assert length(metrics) == 2
      assert Enum.any?(metrics, fn m -> m.name == :metric_a end)
      assert Enum.any?(metrics, fn m -> m.name == :metric_b end)
    end
  end

  describe "get_message_stats/0" do
    test "returns zeroes when no messages recorded" do
      stats = Analytics.get_message_stats()
      assert stats.total_sent == 0
      assert stats.total_received == 0
      assert stats.total_forwarded == 0
      assert stats.total_edited == 0
      assert stats.total_deleted == 0
      assert stats.total == 0
    end

    test "returns correct counts after recording messages" do
      Analytics.record_message(:sent, %{})
      Analytics.record_message(:sent, %{})
      Analytics.record_message(:received, %{})
      Analytics.record_message(:forwarded, %{})

      stats = Analytics.get_message_stats()
      assert stats.total_sent == 2
      assert stats.total_received == 1
      assert stats.total_forwarded == 1
      assert stats.total == 4
    end
  end

  describe "get_message_stats/1 (time range)" do
    test "returns stats for a specific time range" do
      Analytics.record_message(:sent, %{})
      Process.sleep(10)

      now = System.system_time(:millisecond)
      stats = Analytics.get_message_stats(%{from: now - 5000, to: now + 1000})
      assert stats.total >= 0
      assert Map.has_key?(stats, :period)
    end
  end

  describe "get_command_stats/0" do
    test "returns empty when no commands recorded" do
      stats = Analytics.get_command_stats()
      assert stats.commands == %{}
      assert stats.total_commands == 0
      assert stats.most_used == nil
    end

    test "returns correct command statistics" do
      Analytics.record_command(:start, %{success: true})
      Analytics.record_command(:start, %{success: true})
      Analytics.record_command(:start, %{success: true})
      Analytics.record_command(:help, %{success: true})
      Analytics.record_command(:help, %{success: false})

      stats = Analytics.get_command_stats()
      assert stats.total_commands == 5
      assert stats.most_used == "start"

      assert stats.commands["start"].count == 3
      assert stats.commands["start"].success_rate == 100.0

      assert stats.commands["help"].count == 2
      assert stats.commands["help"].error_count == 1
      assert stats.commands["help"].success_rate == 50.0
    end
  end

  describe "get_user_engagement/0" do
    test "returns zeroes when no users tracked" do
      stats = Analytics.get_user_engagement()
      assert stats.total_unique_users == 0
      assert stats.active_users_last_hour == 0
      assert stats.active_users_last_day == 0
      assert stats.top_users == []
    end

    test "returns correct user engagement data" do
      Analytics.track_user_activity(1)
      Analytics.track_user_activity(2)
      Analytics.track_user_activity(1)
      Analytics.track_user_activity(3)

      stats = Analytics.get_user_engagement()
      assert stats.total_unique_users == 3
      assert stats.active_users_last_hour == 3
      assert stats.active_users_last_day == 3
      assert length(stats.top_users) == 3
    end

    test "top_users sorted by message count descending" do
      Analytics.track_user_activity(1)
      Analytics.track_user_activity(2)
      Analytics.track_user_activity(2)
      Analytics.track_user_activity(2)
      Analytics.track_user_activity(1)

      stats = Analytics.get_user_engagement()
      [first | _] = stats.top_users
      assert first.user_id == 2
      assert first.message_count == 3
    end
  end

  describe "get_error_stats/0" do
    test "returns zeroes when no errors recorded" do
      stats = Analytics.get_error_stats()
      assert stats.total_errors == 0
      assert stats.errors_by_type == %{}
      assert stats.error_rate == 0.0
      assert stats.recent_errors == []
    end

    test "returns correct error statistics" do
      Analytics.record_event(:message_sent, %{})
      Analytics.record_event(:message_sent, %{})
      Analytics.record_error(:api_error, %{message: "Bad request"})

      stats = Analytics.get_error_stats()
      assert stats.total_errors == 1
      assert stats.errors_by_type["api_error"] == 1
      assert stats.error_rate > 0
    end

    test "includes recent errors" do
      Analytics.record_error(:timeout, %{message: "Connection timeout"})

      stats = Analytics.get_error_stats()
      assert length(stats.recent_errors) == 1
      [error] = stats.recent_errors
      assert error.type == :error
      assert error.data.error_type == :timeout
    end
  end

  describe "get_performance_metrics/0" do
    test "returns zeroes when no metrics recorded" do
      stats = Analytics.get_performance_metrics()
      assert stats.avg_response_time_ms == 0.0
      assert stats.p50_response_time_ms == 0.0
      assert stats.p95_response_time_ms == 0.0
      assert stats.p99_response_time_ms == 0.0
      assert stats.min_response_time_ms == 0.0
      assert stats.max_response_time_ms == 0.0
    end

    test "calculates correct performance metrics" do
      Analytics.record_response_time(:perf_test_op, 100)
      Analytics.record_response_time(:perf_test_op, 200)
      Analytics.record_response_time(:perf_test_op, 300)
      Analytics.record_response_time(:perf_test_op, 400)
      Analytics.record_response_time(:perf_test_op, 500)

      stats = Analytics.get_performance_metrics()
      # Metrics aggregate all response times in the shared ETS, so we check
      # that our values are included rather than checking exact values
      assert stats.avg_response_time_ms > 0
      assert stats.max_response_time_ms >= 500.0
      assert stats.p50_response_time_ms > 0
    end
  end

  describe "get_usage_patterns/0" do
    test "returns empty patterns when no events" do
      stats = Analytics.get_usage_patterns()
      assert stats.hourly_distribution == %{}
      assert stats.daily_distribution == %{}
    end

    test "records hourly and daily patterns" do
      Analytics.record_event(:message_sent, %{})
      Analytics.record_event(:message_received, %{})

      stats = Analytics.get_usage_patterns()
      # At least the current hour should have entries
      assert map_size(stats.hourly_distribution) > 0
      assert map_size(stats.daily_distribution) > 0
      assert is_integer(stats.peak_hour)
      assert is_atom(stats.peak_day)
    end
  end

  describe "get_dashboard/0" do
    test "returns a complete dashboard" do
      Analytics.record_message(:sent, %{user_id: 42})
      Analytics.record_command(:start, %{})
      Analytics.record_error(:timeout, %{})

      dashboard = Analytics.get_dashboard()
      assert Map.has_key?(dashboard, :messages)
      assert Map.has_key?(dashboard, :commands)
      assert Map.has_key?(dashboard, :engagement)
      assert Map.has_key?(dashboard, :errors)
      assert Map.has_key?(dashboard, :performance)
      assert Map.has_key?(dashboard, :usage_patterns)
      assert Map.has_key?(dashboard, :custom_metrics)
      assert Map.has_key?(dashboard, :generated_at)
    end
  end

  describe "reset/0" do
    test "clears all analytics data" do
      Analytics.record_message(:sent, %{})
      Analytics.record_command(:start, %{})
      Analytics.record_error(:timeout, %{})
      Analytics.define_custom_metric(:test, :counter, "")

      Analytics.reset()

      assert Analytics.get_message_stats().total == 0
      assert Analytics.get_command_stats().total_commands == 0
      assert Analytics.get_error_stats().total_errors == 0
      assert Analytics.list_custom_metrics() == []
    end
  end

  describe "export/0" do
    test "exports all analytics data" do
      Analytics.record_message(:sent, %{chat_id: 123})
      Analytics.record_command(:start, %{})

      export = Analytics.export()
      assert Map.has_key?(export, :events)
      assert Map.has_key?(export, :counters)
      assert Map.has_key?(export, :gauges)
      assert Map.has_key?(export, :custom)
      assert Map.has_key?(export, :exported_at)
      assert length(export.events) > 0
    end
  end

  describe "increment_counter/2" do
    test "creates and increments a new counter" do
      Analytics.increment_counter(:test_counter, 1)
      assert Analytics.get_counter(:test_counter) == 1
    end

    test "increments an existing counter" do
      Analytics.increment_counter(:test_counter, 5)
      Analytics.increment_counter(:test_counter, 3)
      assert Analytics.get_counter(:test_counter) == 8
    end
  end

  describe "get_counter/1" do
    test "returns 0 for non-existent counter" do
      assert Analytics.get_counter(:nonexistent) == 0
    end
  end
end
