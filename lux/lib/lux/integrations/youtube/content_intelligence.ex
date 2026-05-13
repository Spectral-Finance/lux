defmodule Lux.Integrations.YouTube.ContentIntelligence do
  @moduledoc """
  Transport-neutral YouTube content intelligence helpers.

  The module scores video performance, extracts engagement signals, recommends
  optimization actions, predicts posting windows from historical samples, and
  prepares metadata suggestions from topic/trend inputs.
  """

  @doc """
  Scores a video from public metrics and retention data.
  """
  @spec performance_score(map()) :: map()
  def performance_score(video) when is_map(video) do
    views = number(video, :views)
    likes = number(video, :likes)
    comments = number(video, :comments)
    shares = number(video, :shares)
    impressions = number(video, :impressions)
    click_through_rate = ratio(number(video, :clicks), impressions)
    engagement_rate = ratio(likes + comments + shares, max(views, 1))
    retention_rate = ratio(number(video, :average_view_duration_seconds), max(number(video, :duration_seconds), 1))

    %{
      video_id: value(video, :id),
      engagement_rate: engagement_rate,
      click_through_rate: click_through_rate,
      retention_rate: retention_rate,
      score: weighted_score(%{
        engagement_rate: engagement_rate,
        click_through_rate: click_through_rate,
        retention_rate: retention_rate
      })
    }
  end

  @doc """
  Produces prioritized content optimization recommendations.
  """
  @spec recommendations(map()) :: [map()]
  def recommendations(video) when is_map(video) do
    score = performance_score(video)

    []
    |> maybe_recommend(score.click_through_rate < 0.04, :thumbnail, :high, "Improve thumbnail/title hook to raise CTR")
    |> maybe_recommend(score.retention_rate < 0.35, :script, :high, "Tighten intro and pacing to improve retention")
    |> maybe_recommend(score.engagement_rate < 0.03, :engagement, :medium, "Add explicit comment prompt and pinned question")
    |> maybe_recommend(tag_count(video) < 5, :tags, :low, "Add more specific search and topic tags")
    |> Enum.reverse()
  end

  @doc """
  Ranks posting windows by historical engagement.
  """
  @spec posting_windows([map()]) :: [map()]
  def posting_windows(samples) when is_list(samples) do
    samples
    |> Enum.group_by(fn sample -> {value(sample, :weekday), value(sample, :hour)} end)
    |> Enum.map(fn {{weekday, hour}, grouped} ->
      average_score =
        grouped
        |> Enum.map(&number(&1, :engagements))
        |> average()

      %{
        weekday: weekday,
        hour: hour,
        sample_count: length(grouped),
        average_engagements: average_score
      }
    end)
    |> Enum.sort_by(& &1.average_engagements, :desc)
  end

  @doc """
  Builds metadata suggestions for a topic and trend set.
  """
  @spec optimize_metadata(map(), map()) :: map()
  def optimize_metadata(attrs, opts \\ %{}) when is_map(attrs) do
    topic = value(attrs, :topic) || value(attrs, :title) || "Untitled"
    trends = value(opts, :trends) || []
    matched_trends = match_trends(topic, trends)
    primary_tags = value(attrs, :tags) || []
    trend_tags = Enum.map(matched_trends, & &1.term)
    tags = (primary_tags ++ trend_tags) |> Enum.map(&normalize_tag/1) |> Enum.uniq() |> Enum.take(15)

    %{
      title: title_suggestion(topic, matched_trends),
      description: description_suggestion(topic, value(attrs, :summary), tags),
      tags: tags,
      matched_trends: matched_trends
    }
  end

  @doc """
  Matches a content topic to trend records using token overlap.
  """
  @spec match_trends(String.t(), [map()]) :: [map()]
  def match_trends(topic, trends) when is_binary(topic) and is_list(trends) do
    topic_tokens = tokens(topic)

    trends
    |> Enum.map(fn trend ->
      term = value(trend, :term) || value(trend, :topic) || ""
      overlap = MapSet.intersection(topic_tokens, tokens(term)) |> MapSet.size()

      %{
        term: term,
        score: number(trend, :score) + overlap * 10,
        overlap: overlap
      }
    end)
    |> Enum.filter(&(&1.overlap > 0))
    |> Enum.sort_by(& &1.score, :desc)
    |> Enum.take(5)
  end

  @doc """
  Builds an end-to-end optimization report for a video and channel samples.
  """
  @spec content_report(map(), map()) :: map()
  def content_report(video, context \\ %{}) do
    metadata =
      optimize_metadata(
        %{
          topic: value(video, :title),
          summary: value(video, :summary),
          tags: value(video, :tags) || []
        },
        %{trends: value(context, :trends) || []}
      )

    %{
      video_id: value(video, :id),
      performance: performance_score(video),
      recommendations: recommendations(video),
      posting_windows: posting_windows(value(context, :posting_samples) || []),
      metadata: metadata
    }
  end

  defp weighted_score(metrics) do
    raw =
      metrics.engagement_rate * 0.35 +
        metrics.click_through_rate * 0.30 +
        metrics.retention_rate * 0.35

    capped = min(raw, 1.0)
    Float.round(capped * 100, 2)
  end

  defp maybe_recommend(recommendations, true, area, priority, message) do
    [%{area: area, priority: priority, message: message} | recommendations]
  end

  defp maybe_recommend(recommendations, false, _area, _priority, _message), do: recommendations

  defp title_suggestion(topic, []), do: trim_title(topic)

  defp title_suggestion(topic, [trend | _trends]) do
    "#{trim_title(topic)} | #{trim_title(trend.term)}"
    |> trim_title()
  end

  defp description_suggestion(topic, nil, tags), do: description_suggestion(topic, "", tags)

  defp description_suggestion(topic, summary, tags) do
    tag_line =
      tags
      |> Enum.map(&("#" <> &1))
      |> Enum.join(" ")

    [summary, "Topic: #{topic}", tag_line]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n\n")
  end

  defp trim_title(title) do
    title
    |> String.trim()
    |> String.slice(0, 95)
  end

  defp tag_count(video), do: (value(video, :tags) || []) |> length()

  defp normalize_tag(tag) do
    tag
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_ -]/, "")
    |> String.trim()
  end

  defp tokens(text) do
    text
    |> String.downcase()
    |> String.split(~r/[^a-z0-9]+/, trim: true)
    |> MapSet.new()
  end

  defp average([]), do: 0.0
  defp average(values), do: Enum.sum(values) / length(values)

  defp ratio(_numerator, 0), do: 0.0
  defp ratio(numerator, denominator), do: numerator / denominator

  defp number(map, key) do
    case value(map, key) do
      value when is_integer(value) -> value
      value when is_float(value) -> value
      value when is_binary(value) ->
        case Float.parse(value) do
          {parsed, _rest} -> parsed
          :error -> 0
        end

      _other ->
        0
    end
  end

  defp value(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp value(_map, _key), do: nil
end
