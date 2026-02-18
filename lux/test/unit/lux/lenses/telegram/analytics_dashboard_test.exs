defmodule Lux.Lenses.Telegram.AnalyticsDashboardTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Lenses.Telegram.AnalyticsDashboard
  alias Lux.Integrations.Telegram.Analytics

  setup do
    start_supervised!({Analytics, [name: :"test_#{:erlang.unique_integer([:positive])}", cleanup_interval_ms: 0]})
    Analytics.reset()
    :ok
  end

  describe "focus/2" do
    test "returns full dashboard with section 'all'" do
      Analytics.record_message(:sent, %{user_id: 42})
      Analytics.record_command(:start, %{})

      assert {:ok, dashboard} = AnalyticsDashboard.focus(%{section: "all"})
      assert Map.has_key?(dashboard, :messages)
      assert Map.has_key?(dashboard, :commands)
      assert Map.has_key?(dashboard, :engagement)
      assert Map.has_key?(dashboard, :errors)
      assert Map.has_key?(dashboard, :performance)
      assert Map.has_key?(dashboard, :usage_patterns)
    end

    test "returns message stats with section 'messages'" do
      Analytics.record_message(:sent, %{})
      Analytics.record_message(:received, %{})

      assert {:ok, stats} = AnalyticsDashboard.focus(%{section: "messages"})
      assert Map.has_key?(stats, :total_sent)
      assert Map.has_key?(stats, :total_received)
      assert stats.total_sent == 1
      assert stats.total_received == 1
    end

    test "returns command stats with section 'commands'" do
      Analytics.record_command(:start, %{})

      assert {:ok, stats} = AnalyticsDashboard.focus(%{section: "commands"})
      assert Map.has_key?(stats, :commands)
      assert Map.has_key?(stats, :total_commands)
    end

    test "returns engagement stats with section 'engagement'" do
      Analytics.track_user_activity(42)

      assert {:ok, stats} = AnalyticsDashboard.focus(%{section: "engagement"})
      assert Map.has_key?(stats, :total_unique_users)
      assert stats.total_unique_users == 1
    end

    test "returns error stats with section 'errors'" do
      Analytics.record_error(:timeout, %{})

      assert {:ok, stats} = AnalyticsDashboard.focus(%{section: "errors"})
      assert Map.has_key?(stats, :total_errors)
      assert stats.total_errors == 1
    end

    test "returns performance stats with section 'performance'" do
      Analytics.record_response_time(:op, 100)

      assert {:ok, stats} = AnalyticsDashboard.focus(%{section: "performance"})
      assert Map.has_key?(stats, :avg_response_time_ms)
    end

    test "returns usage patterns with section 'usage_patterns'" do
      Analytics.record_event(:message_sent, %{})

      assert {:ok, stats} = AnalyticsDashboard.focus(%{section: "usage_patterns"})
      assert Map.has_key?(stats, :hourly_distribution)
      assert Map.has_key?(stats, :daily_distribution)
    end

    test "defaults to 'all' when section not specified" do
      assert {:ok, dashboard} = AnalyticsDashboard.focus(%{})
      assert Map.has_key?(dashboard, :messages)
      assert Map.has_key?(dashboard, :commands)
    end

    test "returns error for unknown section" do
      assert {:error, "Unknown section: invalid"} =
               AnalyticsDashboard.focus(%{section: "invalid"})
    end
  end

  describe "view/0" do
    test "returns a valid lens struct" do
      lens = AnalyticsDashboard.view()
      assert lens.name == "Telegram Analytics Dashboard"
      assert lens.method == :get
      assert Map.has_key?(lens.schema.properties, :section)
    end
  end
end
