defmodule Lux.YouTube.ContentIntelligence.AudienceEngagement do
  @moduledoc """
  Audience engagement, loyalty scoring, traffic source decomposition,
  and cohort segmentation engine.
  """

  @type engagement_profile :: %{
          loyalty_score: float(),
          returning_viewer_ratio: float(),
          subscriber_watch_ratio: float(),
          like_ratio: float(),
          comment_density_per_1k: float(),
          share_rate_percentage: float(),
          traffic_source_health: :search_driven | :browse_driven | :suggested_viral | :external,
          primary_traffic_source: String.t(),
          engagement_grade: :s | :a | :b | :c | :f
        }

  @doc """
  Analyzes audience interaction data and derives engagement health profiles.
  """
  @spec analyze_audience(map()) :: engagement_profile()
  def analyze_audience(data) when is_map(data) do
    views = max(Map.get(data, :views, Map.get(data, "views", 1)), 1)
    likes = Map.get(data, :likes, Map.get(data, "likes", 0))
    comments = Map.get(data, :comments, Map.get(data, "comments", 0))
    shares = Map.get(data, :shares, Map.get(data, "shares", 0))

    returning_viewers = Map.get(data, :returning_viewers, Map.get(data, "returning_viewers", div(views, 3)))
    sub_watch_time = Map.get(data, :sub_watch_time_pct, Map.get(data, "sub_watch_time_pct", 35.0))

    traffic_sources = Map.get(data, :traffic_sources, Map.get(data, "traffic_sources", %{
      "browse" => 45.0,
      "suggested" => 35.0,
      "search" => 15.0,
      "external" => 5.0
    }))

    returning_ratio = Float.round(returning_viewers / views, 3)
    like_ratio = Float.round((likes / views) * 100, 2)
    comment_density = Float.round((comments / views) * 1000, 2)
    share_rate = Float.round((shares / views) * 100, 2)

    primary_source = determine_primary_source(traffic_sources)

    traffic_health =
      case primary_source do
        "suggested" -> :suggested_viral
        "browse" -> :browse_driven
        "search" -> :search_driven
        _ -> :external
      end

    loyalty_score = calculate_loyalty_score(returning_ratio, sub_watch_time, comment_density)
    grade = grade_engagement(like_ratio, comment_density, loyalty_score)

    %{
      loyalty_score: loyalty_score,
      returning_viewer_ratio: returning_ratio,
      subscriber_watch_ratio: sub_watch_time,
      like_ratio: like_ratio,
      comment_density_per_1k: comment_density,
      share_rate_percentage: share_rate,
      traffic_source_health: traffic_health,
      primary_traffic_source: primary_source,
      engagement_grade: grade
    }
  end

  defp determine_primary_source(sources) when is_map(sources) do
    Enum.max_by(sources, fn {_src, pct} -> pct end, fn -> {"browse", 0.0} end)
    |> elem(0)
    |> to_string()
    |> String.downcase()
  end

  defp calculate_loyalty_score(returning_ratio, sub_watch_pct, comment_density) do
    score = (returning_ratio * 40.0) + (sub_watch_pct * 0.4) + min(comment_density * 2.0, 20.0)
    Float.round(min(max(score, 0.0), 100.0), 1)
  end

  defp grade_engagement(like_ratio, comment_density, loyalty_score) do
    cond do
      like_ratio >= 6.0 and comment_density >= 12.0 and loyalty_score >= 70.0 -> :s
      like_ratio >= 4.0 and comment_density >= 6.0 and loyalty_score >= 50.0 -> :a
      like_ratio >= 2.5 and comment_density >= 3.0 -> :b
      like_ratio >= 1.0 -> :c
      true -> :f
    end
  end
end
