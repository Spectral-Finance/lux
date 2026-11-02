defmodule Lux.Integrations.Telegram.Analytics.UsagePatternAnalyzer do
  @moduledoc """
  Analyzes temporal usage patterns, peak hours, day-of-week trends,
  and audience activity distributions for Telegram communities.
  """

  @doc """
  Computes temporal patterns and activity distributions from events.
  """
  @spec analyze(list(map())) :: map()
  def analyze(events) when is_list(events) do
    hourly_distribution =
      events
      |> Enum.frequencies_by(fn e -> e.timestamp.hour end)
      |> fill_all_hours()

    dow_distribution =
      events
      |> Enum.frequencies_by(fn e -> Date.day_of_week(DateTime.to_date(e.timestamp)) end)
      |> fill_all_days()

    peak_hour =
      hourly_distribution
      |> Enum.max_by(fn {_hour, count} -> count end, fn -> {0, 0} end)
      |> elem(0)

    quiet_hour =
      hourly_distribution
      |> Enum.min_by(fn {_hour, count} -> count end, fn -> {0, 0} end)
      |> elem(0)

    busiest_day =
      dow_distribution
      |> Enum.max_by(fn {_day, count} -> count end, fn -> {1, 0} end)
      |> elem(0)
      |> day_name()

    %{
      hourly_distribution: hourly_distribution,
      day_of_week_distribution: dow_distribution,
      peak_hour_utc: peak_hour,
      quiet_hour_utc: quiet_hour,
      busiest_day: busiest_day
    }
  end

  defp fill_all_hours(freqs) do
    Map.new(0..23, fn hour -> {hour, Map.get(freqs, hour, 0)} end)
  end

  defp fill_all_days(freqs) do
    Map.new(1..7, fn day -> {day, Map.get(freqs, day, 0)} end)
  end

  defp day_name(1), do: "Monday"
  defp day_name(2), do: "Tuesday"
  defp day_name(3), do: "Wednesday"
  defp day_name(4), do: "Thursday"
  defp day_name(5), do: "Friday"
  defp day_name(6), do: "Saturday"
  defp day_name(7), do: "Sunday"
  defp day_name(_), do: "Unknown"
end
