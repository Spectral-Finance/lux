defmodule Lux.Integrations.Telegram.Analytics.UsagePatternAnalyzerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.Analytics.UsagePatternAnalyzer

  describe "UsagePatternAnalyzer" do
    test "determines peak and quiet hours and busiest day" do
      # Create events on Monday at 14:00 UTC
      {:ok, dt1, _} = DateTime.from_iso8601("2024-01-01T14:00:00Z") # Monday
      {:ok, dt2, _} = DateTime.from_iso8601("2024-01-01T14:30:00Z") # Monday
      {:ok, dt3, _} = DateTime.from_iso8601("2024-01-02T03:00:00Z") # Tuesday

      events = [
        %{timestamp: dt1},
        %{timestamp: dt2},
        %{timestamp: dt3}
      ]

      result = UsagePatternAnalyzer.analyze(events)
      assert result.peak_hour_utc == 14
      assert result.busiest_day == "Monday"
      assert Map.has_key?(result.hourly_distribution, 14)
      assert result.hourly_distribution[14] == 2
    end
  end
end
