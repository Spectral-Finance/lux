defmodule Lux.Integrations.YouTube.ContentIntelligence do
  @moduledoc """
  YouTube content analysis, optimization, and prediction helpers.

  The model is deterministic and explainable: it combines YouTube Data API
  records, Analytics API rows, trend samples, and historical channel samples
  into optimization reports that agents can inspect or act on.
  """

  alias Lux.Integrations.YouTube.Client

  @default_model %{
    base_views: 1_000.0,
    engagement_weight: 0.35,
    retention_weight: 0.30,
    ctr_weight: 0.25,
    trend_weight: 0.10
  }

  @doc """
  Collects and processes video records from YouTube Data API responses.
  """
  def process_video_records(%{"items" => items}) when is_list(items) do
    Enum.map(items, &video_record/1)
  end

  def process_video_records(items) when is_list(items), do: Enum.map(items, &video_record/1)

  @doc """
  Fetches video records through the API client, then processes metrics.
  """
  def collect_video_analytics(video_ids, opts \\ %{}) do
    with {:ok, body} <- Client.videos(video_ids, opts) do
      {:ok, process_video_records(body)}
    end
  end

  @doc """
  Parses YouTube Analytics API rows into maps keyed by metric names.
  """
  def process_analytics_report(%{"columnHeaders" => headers, "rows" => rows})
      when is_list(rows) do
    names = Enum.map(headers, & &1["name"])
    Enum.map(rows, fn row -> names |> Enum.zip(row) |> Map.new() end)
  end

  def process_analytics_report(_report), do: []

  @doc """
  Scores audience engagement from views, likes, comments, shares, CTR, and retention.
  """
  def engagement_analysis(video) do
    views = number(video, :views)
    likes = number(video, :likes)
    comments = number(video, :comments)
    shares = number(video, :shares)
    impressions = number(video, :impressions)
    clicks = number(video, :clicks)
    duration = max(number(video, :duration_seconds), 1)
    average_view_duration = number(video, :average_view_duration_seconds)

    %{
      engagement_rate: ratio(likes + comments + shares, max(views, 1)),
      comment_rate: ratio(comments, max(views, 1)),
      click_through_rate: ratio(clicks, max(impressions, 1)),
      retention_rate: ratio(average_view_duration, duration)
    }
  end

  @doc """
  Trains an explainable baseline prediction model from historical samples.
  """
  def train_performance_model(samples) when is_list(samples) do
    base_views =
      samples
      |> Enum.map(&number(&1, :views))
      |> average()
      |> max(1.0)

    Map.put(@default_model, :base_views, base_views)
  end

  @doc """
  Predicts view and engagement bands for a candidate video.
  """
  def predict_performance(candidate, model \\ @default_model) do
    engagement = engagement_analysis(candidate)
    trend_score = number(candidate, :trend_score)

    multiplier =
      0.5 +
        engagement.engagement_rate * 10 * model.engagement_weight +
        engagement.retention_rate * model.retention_weight +
        engagement.click_through_rate * 5 * model.ctr_weight +
        min(trend_score / 100, 1) * model.trend_weight

    mid = round(model.base_views * max(multiplier, 0.1))

    %{
      predicted_views: %{low: round(mid * 0.65), mid: mid, high: round(mid * 1.6)},
      predicted_engagement_rate: Float.round(engagement.engagement_rate, 4),
      confidence: confidence(candidate, engagement),
      drivers: engagement
    }
  end

  @doc """
  Ranks optimal posting windows from historical engagement samples.
  """
  def posting_time_prediction(samples) when is_list(samples) do
    samples
    |> Enum.group_by(fn sample -> {value(sample, :weekday), value(sample, :hour)} end)
    |> Enum.map(fn {{weekday, hour}, grouped} ->
      %{
        weekday: weekday,
        hour: hour,
        sample_count: length(grouped),
        expected_engagements: grouped |> Enum.map(&number(&1, :engagements)) |> average()
      }
    end)
    |> Enum.sort_by(& &1.expected_engagements, :desc)
  end

  @doc """
  Matches trends to a topic and ranks by token overlap plus trend score.
  """
  def trend_analysis(topic, trends) when is_binary(topic) and is_list(trends) do
    topic_tokens = tokens(topic)

    trends
    |> Enum.map(fn trend ->
      term = value(trend, :term) || value(trend, :topic) || ""
      overlap = MapSet.intersection(topic_tokens, tokens(term)) |> MapSet.size()
      score = number(trend, :score) + overlap * 10
      %{term: term, score: score, overlap: overlap}
    end)
    |> Enum.filter(&(&1.overlap > 0))
    |> Enum.sort_by(& &1.score, :desc)
  end

  @doc """
  Generates title, tags, and description from a topic and matched trends.
  """
  def generate_metadata(attrs, opts \\ %{}) do
    topic = value(attrs, :topic) || value(attrs, :title) || "Untitled"
    summary = value(attrs, :summary) || "A practical guide to #{topic}."
    base_tags = value(attrs, :tags) || []
    trends = trend_analysis(topic, value(opts, :trends) || [])
    trend_terms = Enum.map(trends, & &1.term)
    topic_tokens = tokens(topic) |> MapSet.to_list()

    tags =
      (base_tags ++ trend_terms ++ topic_tokens)
      |> Enum.map(&normalize_tag/1)
      |> Enum.uniq()
      |> Enum.take(15)

    %{
      title: optimized_title(topic, trends),
      thumbnail: thumbnail_brief(topic, trends),
      description: description(topic, summary, tags),
      tags: tags,
      matched_trends: trends
    }
  end

  @doc """
  Produces prioritized content recommendations.
  """
  def recommendations(video) do
    metrics = engagement_analysis(video)

    []
    |> maybe_add(
      metrics.click_through_rate < 0.04,
      :thumbnail,
      :high,
      "Improve title/thumbnail hook to raise CTR"
    )
    |> maybe_add(
      metrics.retention_rate < 0.35,
      :script,
      :high,
      "Shorten intro and improve pacing"
    )
    |> maybe_add(
      metrics.engagement_rate < 0.03,
      :engagement,
      :medium,
      "Add a pinned question and explicit comment prompt"
    )
    |> maybe_add(
      length(value(video, :tags) || []) < 5,
      :tags,
      :low,
      "Add more specific search and trend tags"
    )
    |> Enum.reverse()
  end

  @doc """
  Runs the complete optimization workflow from raw records and context.
  """
  def content_report(video, context \\ %{}) do
    model = train_performance_model(value(context, :historical_samples) || [])
    metadata = generate_metadata(video, %{trends: value(context, :trends) || []})

    candidate =
      Map.merge(video, %{
        trend_score: metadata.matched_trends |> Enum.map(& &1.score) |> Enum.sum()
      })

    %{
      video_id: value(video, :id),
      analytics: engagement_analysis(video),
      prediction: predict_performance(candidate, model),
      metadata: metadata,
      recommendations: recommendations(video),
      posting_windows: posting_time_prediction(value(context, :posting_samples) || [])
    }
  end

  defp video_record(item) do
    statistics = item["statistics"] || %{}
    snippet = item["snippet"] || %{}
    details = item["contentDetails"] || %{}

    %{
      id: item["id"],
      title: snippet["title"],
      description: snippet["description"],
      channel_id: snippet["channelId"],
      published_at: snippet["publishedAt"],
      tags: snippet["tags"] || [],
      views: integer(statistics["viewCount"]),
      likes: integer(statistics["likeCount"]),
      comments: integer(statistics["commentCount"]),
      duration_seconds: iso8601_duration_seconds(details["duration"])
    }
  end

  defp optimized_title(topic, []), do: trim("#{topic}: A Practical Growth Guide", 70)

  defp optimized_title(topic, [trend | _]),
    do: trim("#{topic}: #{trend.term} Growth Playbook", 70)

  defp thumbnail_brief(topic, []),
    do: %{
      primary_text: trim(topic, 32),
      visual_cues: ["single focal point", "high contrast subject", "clear outcome"],
      rationale: "Use the core topic as the thumbnail hook when no matched trend is available"
    }

  defp thumbnail_brief(_topic, [trend | _]),
    do: %{
      primary_text: trim(trend.term, 32),
      visual_cues: ["trend phrase foreground", "high contrast subject", "clear outcome"],
      rationale: "Use the highest matched trend as the thumbnail hook"
    }

  defp description(topic, summary, tags) do
    hashtags =
      tags
      |> Enum.take(5)
      |> Enum.map(&("#" <> String.replace(&1, " ", "")))
      |> Enum.join(" ")

    "#{summary}\n\nIn this video: #{topic}\n\n#{hashtags}"
  end

  defp maybe_add(recs, false, _area, _priority, _message), do: recs

  defp maybe_add(recs, true, area, priority, message),
    do: [%{area: area, priority: priority, message: message} | recs]

  defp confidence(video, engagement) do
    filled =
      [:title, :tags, :views, :likes, :comments, :duration_seconds]
      |> Enum.count(&(not is_nil(value(video, &1))))

    Float.round(min(0.95, 0.25 + filled / 10 + engagement.retention_rate * 0.2), 2)
  end

  defp tokens(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9 ]/, " ")
    |> String.split()
    |> MapSet.new()
  end

  defp tokens(_text), do: MapSet.new()

  defp normalize_tag(tag), do: tag |> to_string() |> String.trim() |> String.downcase()

  defp trim(text, max_length) do
    if String.length(text) <= max_length, do: text, else: String.slice(text, 0, max_length - 1)
  end

  defp ratio(_num, 0), do: 0.0
  defp ratio(num, den), do: num / den

  defp average([]), do: 0.0
  defp average(values), do: Enum.sum(values) / length(values)

  defp number(map, key), do: value(map, key) |> number_value()
  defp number_value(nil), do: 0.0
  defp number_value(value) when is_integer(value), do: value * 1.0
  defp number_value(value) when is_float(value), do: value
  defp number_value(value) when is_binary(value), do: value |> Float.parse() |> elem_or_zero()
  defp number_value(_value), do: 0.0

  defp integer(nil), do: 0
  defp integer(value) when is_integer(value), do: value

  defp integer(value) when is_binary(value),
    do: value |> Integer.parse() |> elem_or_zero() |> round()

  defp integer(_value), do: 0

  defp elem_or_zero({number, _rest}), do: number
  defp elem_or_zero(:error), do: 0

  defp value(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, to_string(key))
  defp value(_map, _key), do: nil

  defp iso8601_duration_seconds(nil), do: nil

  defp iso8601_duration_seconds(duration) do
    captures =
      Regex.named_captures(~r/PT(?:(?<h>\d+)H)?(?:(?<m>\d+)M)?(?:(?<s>\d+)S)?/, duration) || %{}

    integer(captures["h"]) * 3600 + integer(captures["m"]) * 60 + integer(captures["s"])
  end
end
