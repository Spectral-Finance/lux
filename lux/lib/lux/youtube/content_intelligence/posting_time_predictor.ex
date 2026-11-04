defmodule Lux.YouTube.ContentIntelligence.PostingTimePredictor do
  @moduledoc """
  Optimal posting time prediction for YouTube content intelligence.

  Provides peak viewer activity heatmaps, timezone weighting,
  lead-time buffering, and schedule slot scoring.
  """

  @type time_slot :: %{hour: non_neg_integer(), day_of_week: non_neg_integer(),
                       predicted_views: non_neg_integer(), score: float()}

  @doc """
  Predicts optimal posting times based on historical performance.

  ## Parameters

    * `historical_performance` - List of %{hour, day_of_week, views} maps
    * `timezone` - Channel timezone (e.g., "UTC", "EST", "PST")
    * `lead_time_hours` - Hours in advance to schedule (default: 24)

  ## Returns

    * `{:ok, result}` - Posting time predictions
    * `{:error, reason}` - If input is invalid
  """
  def predict(input) when is_map(input) do
    with {:ok, validated} <- validate_input(input) do
      heatmap = build_heatmap(validated.historical_performance)
      peak_times = identify_peak_times(heatmap)
      scored_slots = score_slots(heatmap, validated.timezone, validated.lead_time_hours)

      {:ok, %{
        peak_viewer_activity: peak_times,
        recommended_slots: Enum.take(scored_slots, 5),
        timezone_weighted_times: adjust_for_timezone(heatmap, validated.timezone),
        lead_time_buffer: validated.lead_time_hours,
        heatmap: heatmap
      }}
    end
  end

  def predict(_input), do: {:error, :invalid_input}

  @doc """
  Builds a heatmap of viewer activity by hour and day.
  """
  def build_heatmap(performance_data) when is_list(performance_data) do
    Enum.reduce(performance_data, %{}, fn entry, acc ->
      key = "#{Map.get(entry, :hour, 12)}-#{Map.get(entry, :day_of_week, 1)}"
      views = Map.get(entry, :views, 0)
      current = Map.get(acc, key, %{hour: Map.get(entry, :hour, 12), day_of_week: Map.get(entry, :day_of_week, 1), total_views: 0, count: 0})
      Map.put(acc, key, %{current | total_views: current.total_views + views, count: current.count + 1})
    end)
    |> Map.values()
    |> Enum.map(fn entry ->
      %{"hour" => entry.hour, "day_of_week" => entry.day_of_week,
        "avg_views" => round(entry.total_views / entry.count), "count" => entry.count}
    end)
    |> Enum.sort_by(fn e -> -e["avg_views"] end)
  end

  def build_heatmap(_), do: {:error, :invalid_input}

  @doc """
  Identifies peak viewing times from heatmap data.
  """
  def identify_peak_times(heatmap) when is_list(heatmap) do
    Enum.take(heatmap, 5)
    |> Enum.map(fn entry ->
      %{"hour" => entry["hour"], "day_of_week" => entry["day_of_week"],
        "predicted_views" => entry["avg_views"], "score" => 1.0}
    end)
  end

  def identify_peak_times(_), do: {:error, :invalid_input}

  @doc """
  Scores time slots for posting recommendations.
  """
  def score_slots(heatmap, timezone, lead_time_hours) when is_list(heatmap) and is_binary(timezone) do
    Enum.map(heatmap, fn entry ->
      base_score = if entry["avg_views"] > 0, do: entry["avg_views"] / 1000.0, else: 0.0
      timezone_factor = timezone_weight(timezone, entry["hour"])
      lead_factor = if lead_time_hours > 0 and lead_time_hours <= 48, do: 1.0, else: 0.5
      %{"hour" => entry["hour"], "day_of_week" => entry["day_of_week"],
        "predicted_views" => entry["avg_views"],
        "score" => round(base_score * timezone_factor * lead_factor * 100) / 100}
    end)
    |> Enum.sort_by(fn e -> -e["score"] end)
  end

  def score_slots(_, _, _), do: {:error, :invalid_input}

  @doc """
  Adjusts times for the channel's timezone.
  """
  def adjust_for_timezone(heatmap, timezone) when is_list(heatmap) and is_binary(timezone) do
    offset = timezone_offset(timezone)
    Enum.map(heatmap, fn entry ->
      adjusted_hour = rem(entry["hour"] + offset, 24)
      %{"hour" => adjusted_hour, "day_of_week" => entry["day_of_week"],
        "original_hour" => entry["hour"], "timezone" => timezone,
        "predicted_views" => entry["avg_views"]}
    end)
  end

  def adjust_for_timezone(_, _), do: {:error, :invalid_input}

  # Private helpers

  defp validate_input(input) do
    required = [:historical_performance, :timezone]

    missing = Enum.filter(required, fn key -> not Map.has_key?(input, key) end)

    if missing != [] do
      {:error, {:missing_fields, missing}}
    else
      cond do
        not is_list(input.historical_performance) -> {:error, {:invalid_value, :historical_performance}}
        not is_binary(input.timezone) -> {:error, {:invalid_value, :timezone}}
        true -> {:ok, Map.put(input, :lead_time_hours, Map.get(input, :lead_time_hours, 24))}
      end
    end
  end

  defp timezone_weight(_timezone, hour) when is_integer(hour) do
    # Peak hours weight higher (18-22 local time)
    cond do
      hour in 18..22 -> 1.2
      hour in 12..17 -> 1.0
      hour in 6..11 -> 0.8
      true -> 0.5
    end
  end

  defp timezone_offset(timezone) do
    case timezone do
      "UTC" -> 0
      "EST" -> -5
      "PST" -> -8
      "GMT" -> 0
      _ -> 0
    end
  end
end