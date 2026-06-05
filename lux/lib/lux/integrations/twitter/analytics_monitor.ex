defmodule Lux.Integrations.Twitter.AnalyticsMonitor do
  @moduledoc """
  Credential-free Twitter/X analytics and monitoring core.

  This module turns imported Twitter/X account snapshots, tweet metrics, mentions,
  follower counts, hashtag data, and custom metric definitions into a deterministic
  monitoring report. It intentionally does not call the Twitter API or mutate an
  account; live collection belongs behind a future transport adapter.
  """

  @positive_words ~w(awesome excellent great good love loved thanks thank amazing win winner useful helpful bullish)
  @negative_words ~w(bad broken hate hated terrible awful scam spam rug useless angry disappointed)

  @doc """
  Builds an analytics report from string-keyed or atom-keyed payloads.
  """
  @spec build_report(map()) :: {:ok, map()} | {:error, String.t()}
  def build_report(payload) when is_map(payload) do
    tweets = payload |> get_list(:tweets) |> Enum.map(&normalize_tweet/1)
    mentions = payload |> get_list(:mentions) |> Enum.map(&normalize_mention/1)
    follower_snapshots = normalize_follower_snapshots(get_list(payload, :follower_snapshots))
    custom_metrics = evaluate_custom_metrics(get_list(payload, :custom_metrics), tweets)

    tweet_metrics = Enum.map(tweets, &tweet_report/1)
    totals = aggregate_totals(tweet_metrics)
    hashtags = aggregate_hashtags(tweet_metrics)
    sentiment = aggregate_sentiment(mentions)
    follower_growth = calculate_follower_growth(follower_snapshots)
    alerts = evaluate_alerts(get_map(payload, :alert_thresholds), totals, hashtags, sentiment, follower_growth)
    quality_notes = quality_notes(tweets, mentions, follower_snapshots)

    report = %{
      account_id: get_value(payload, :account_id, "unknown"),
      generated_at: get_value(payload, :generated_at, DateTime.utc_now() |> DateTime.to_iso8601()),
      collection_boundary: "offline_import",
      metrics: totals,
      tweet_metrics: tweet_metrics,
      follower_growth: follower_growth,
      hashtag_performance: hashtags,
      mention_sentiment: sentiment,
      custom_metrics: custom_metrics,
      alerts: alerts,
      report_sections: build_sections(totals, hashtags, sentiment, follower_growth, alerts),
      chart_payloads: build_chart_payloads(tweet_metrics, hashtags, follower_growth),
      quality_notes: quality_notes,
      performance: %{
        tweet_count: length(tweets),
        mention_count: length(mentions),
        follower_snapshot_count: length(follower_snapshots),
        bounded_input: true
      }
    }

    {:ok, report}
  end

  def build_report(_payload), do: {:error, "Twitter analytics payload must be a map"}

  defp normalize_tweet(tweet) when is_map(tweet) do
    impressions = tweet |> get_value(:impressions, 0) |> non_negative_number()
    likes = tweet |> get_value(:likes, 0) |> non_negative_number()
    replies = tweet |> get_value(:replies, 0) |> non_negative_number()
    retweets = tweet |> get_value(:retweets, 0) |> non_negative_number()
    quotes = tweet |> get_value(:quotes, 0) |> non_negative_number()
    bookmarks = tweet |> get_value(:bookmarks, 0) |> non_negative_number()
    profile_clicks = tweet |> get_value(:profile_clicks, 0) |> non_negative_number()
    hashtags = tweet |> get_list(:hashtags) |> Enum.map(&normalize_hashtag/1) |> Enum.reject(&(&1 == ""))

    %{
      id: get_value(tweet, :id, nil),
      text: get_value(tweet, :text, ""),
      created_at: get_value(tweet, :created_at, nil),
      impressions: impressions,
      likes: likes,
      replies: replies,
      retweets: retweets,
      quotes: quotes,
      bookmarks: bookmarks,
      profile_clicks: profile_clicks,
      hashtags: hashtags
    }
  end

  defp normalize_tweet(_tweet) do
    %{
      id: nil,
      text: "",
      created_at: nil,
      impressions: 0,
      likes: 0,
      replies: 0,
      retweets: 0,
      quotes: 0,
      bookmarks: 0,
      profile_clicks: 0,
      hashtags: []
    }
  end

  defp normalize_mention(mention) when is_map(mention) do
    text = get_value(mention, :text, "")

    %{
      id: get_value(mention, :id, nil),
      text: text,
      author_id: get_value(mention, :author_id, nil),
      followers_count: mention |> get_value(:followers_count, 0) |> non_negative_number(),
      sentiment: classify_sentiment(text)
    }
  end

  defp normalize_mention(_mention), do: %{id: nil, text: "", author_id: nil, followers_count: 0, sentiment: :neutral}

  defp normalize_follower_snapshots(snapshots) do
    snapshots
    |> Enum.filter(&is_map/1)
    |> Enum.map(fn snapshot ->
      %{
        timestamp: get_value(snapshot, :timestamp, nil),
        count: snapshot |> get_value(:count, 0) |> non_negative_number()
      }
    end)
    |> Enum.sort_by(&to_string(&1.timestamp))
  end

  defp tweet_report(tweet) do
    engagements =
      tweet.likes + tweet.replies + tweet.retweets + tweet.quotes + tweet.bookmarks + tweet.profile_clicks

    %{
      id: tweet.id,
      text: tweet.text,
      created_at: tweet.created_at,
      impressions: tweet.impressions,
      likes: tweet.likes,
      replies: tweet.replies,
      retweets: tweet.retweets,
      quotes: tweet.quotes,
      bookmarks: tweet.bookmarks,
      profile_clicks: tweet.profile_clicks,
      engagements: engagements,
      engagement_rate: safe_ratio(engagements, tweet.impressions),
      amplification_rate: safe_ratio(tweet.retweets + tweet.quotes, tweet.impressions),
      conversation_rate: safe_ratio(tweet.replies, tweet.impressions),
      profile_click_rate: safe_ratio(tweet.profile_clicks, tweet.impressions),
      hashtags: tweet.hashtags,
      sentiment: classify_sentiment(tweet.text),
      quality_notes: tweet_quality_notes(tweet, engagements)
    }
  end

  defp aggregate_totals(tweet_metrics) do
    totals =
      Enum.reduce(
        tweet_metrics,
        %{impressions: 0, engagements: 0, tweet_count: 0, profile_clicks: 0},
        fn tweet, acc ->
          %{
            impressions: acc.impressions + tweet.impressions,
            engagements: acc.engagements + tweet.engagements,
            tweet_count: acc.tweet_count + 1,
            profile_clicks: acc.profile_clicks + round(tweet.profile_click_rate * tweet.impressions)
          }
        end
      )

    Map.merge(totals, %{
      engagement_rate: safe_ratio(totals.engagements, totals.impressions),
      average_engagements_per_tweet: safe_ratio(totals.engagements, max(totals.tweet_count, 1)),
      profile_click_rate: safe_ratio(totals.profile_clicks, totals.impressions)
    })
  end

  defp aggregate_hashtags(tweet_metrics) do
    tweet_metrics
    |> Enum.flat_map(fn tweet ->
      Enum.map(tweet.hashtags, fn hashtag ->
        {hashtag, tweet.impressions, tweet.engagements}
      end)
    end)
    |> Enum.reduce(%{}, fn {hashtag, impressions, engagements}, acc ->
      current = Map.get(acc, hashtag, %{hashtag: hashtag, uses: 0, impressions: 0, engagements: 0})

      Map.put(acc, hashtag, %{
        current
        | uses: current.uses + 1,
          impressions: current.impressions + impressions,
          engagements: current.engagements + engagements
      })
    end)
    |> Map.values()
    |> Enum.map(fn row -> Map.put(row, :engagement_rate, safe_ratio(row.engagements, row.impressions)) end)
    |> Enum.sort_by(fn row -> {-row.engagements, row.hashtag} end)
  end

  defp calculate_follower_growth([]) do
    %{
      start_count: 0,
      end_count: 0,
      delta: 0,
      growth_rate: 0.0,
      observations: 0,
      trend: :unknown
    }
  end

  defp calculate_follower_growth(snapshots) do
    first = List.first(snapshots)
    last = List.last(snapshots)
    delta = last.count - first.count
    growth_rate = safe_ratio(delta, max(first.count, 1))

    %{
      start_count: first.count,
      end_count: last.count,
      delta: delta,
      growth_rate: growth_rate,
      observations: length(snapshots),
      trend: growth_trend(delta)
    }
  end

  defp aggregate_sentiment(mentions) do
    counts = Enum.frequencies_by(mentions, & &1.sentiment)
    total = length(mentions)

    %{
      sample_size: total,
      positive: Map.get(counts, :positive, 0),
      neutral: Map.get(counts, :neutral, 0),
      negative: Map.get(counts, :negative, 0),
      negative_ratio: safe_ratio(Map.get(counts, :negative, 0), max(total, 1)),
      high_influence_negative_mentions:
        mentions
        |> Enum.filter(&(&1.sentiment == :negative and &1.followers_count >= 10_000))
        |> Enum.map(&Map.take(&1, [:id, :author_id, :followers_count, :text]))
    }
  end

  defp evaluate_custom_metrics(definitions, tweet_metrics) do
    Enum.map(definitions, fn definition ->
      name = definition |> get_value(:name, "custom_metric") |> to_string()
      numerator_field = definition |> get_value(:numerator, "engagements") |> to_metric()
      denominator_field = definition |> get_value(:denominator, "impressions") |> to_metric()
      numerator = sum_metric(tweet_metrics, numerator_field)
      denominator = sum_metric(tweet_metrics, denominator_field)

      %{
        name: name,
        numerator: numerator_field,
        denominator: denominator_field,
        value: safe_ratio(numerator, denominator),
        numerator_value: numerator,
        denominator_value: denominator
      }
    end)
  end

  defp evaluate_alerts(thresholds, totals, hashtags, sentiment, follower_growth) do
    []
    |> maybe_alert(
      :low_engagement_rate,
      totals.engagement_rate,
      get_value(thresholds, :engagement_rate_below, nil),
      &(&1 < &2),
      "Engagement rate is below threshold"
    )
    |> maybe_alert(
      :high_negative_sentiment,
      sentiment.negative_ratio,
      get_value(thresholds, :negative_sentiment_above, nil),
      &(&1 > &2),
      "Negative mention ratio is above threshold"
    )
    |> maybe_alert(
      :low_follower_growth,
      follower_growth.growth_rate,
      get_value(thresholds, :follower_growth_below, nil),
      &(&1 < &2),
      "Follower growth is below threshold"
    )
    |> add_hashtag_alerts(hashtags, get_value(thresholds, :hashtag_engagement_below, nil))
  end

  defp maybe_alert(alerts, _metric, _value, nil, _predicate, _message), do: alerts

  defp maybe_alert(alerts, metric, value, threshold, predicate, message) do
    threshold = percentage_or_number(threshold)

    if predicate.(value, threshold) do
      [
        %{
          metric: metric,
          severity: alert_severity(metric),
          value: value,
          threshold: threshold,
          message: message
        }
        | alerts
      ]
    else
      alerts
    end
  end

  defp add_hashtag_alerts(alerts, _hashtags, nil), do: alerts

  defp add_hashtag_alerts(alerts, hashtags, threshold) do
    threshold = percentage_or_number(threshold)

    hashtag_alerts =
      hashtags
      |> Enum.filter(&(&1.uses >= 2 and &1.engagement_rate < threshold))
      |> Enum.map(fn hashtag ->
        %{
          metric: :low_hashtag_engagement,
          severity: :warning,
          scope: hashtag.hashtag,
          value: hashtag.engagement_rate,
          threshold: threshold,
          message: "Hashtag engagement is below threshold"
        }
      end)

    hashtag_alerts ++ alerts
  end

  defp build_sections(totals, hashtags, sentiment, follower_growth, alerts) do
    %{
      summary: %{
        tweet_count: totals.tweet_count,
        impressions: totals.impressions,
        engagements: totals.engagements,
        engagement_rate: totals.engagement_rate
      },
      recommendations: recommendations(totals, hashtags, sentiment, follower_growth),
      alert_summary: %{
        count: length(alerts),
        critical: Enum.count(alerts, &(&1.severity == :critical)),
        warning: Enum.count(alerts, &(&1.severity == :warning))
      }
    }
  end

  defp build_chart_payloads(tweet_metrics, hashtags, follower_growth) do
    %{
      engagement_by_tweet:
        Enum.map(tweet_metrics, fn tweet ->
          %{id: tweet.id, impressions: tweet.impressions, engagements: tweet.engagements}
        end),
      hashtag_engagement:
        Enum.map(hashtags, fn hashtag ->
          %{hashtag: hashtag.hashtag, uses: hashtag.uses, engagement_rate: hashtag.engagement_rate}
        end),
      follower_growth: follower_growth
    }
  end

  defp recommendations(totals, hashtags, sentiment, follower_growth) do
    []
    |> maybe_recommend(totals.engagement_rate < 0.02, "Refresh hooks and CTAs on low-engagement tweets.")
    |> maybe_recommend(sentiment.negative_ratio > 0.25, "Route negative mentions to review before auto replies.")
    |> maybe_recommend(follower_growth.delta <= 0, "Run a follower growth experiment with pinned content and creator replies.")
    |> maybe_recommend(length(hashtags) == 0, "Add tracked hashtags so future reports can compare topic performance.")
    |> Enum.reverse()
  end

  defp maybe_recommend(recommendations, true, recommendation), do: [recommendation | recommendations]
  defp maybe_recommend(recommendations, false, _recommendation), do: recommendations

  defp quality_notes(tweets, mentions, follower_snapshots) do
    []
    |> maybe_note(tweets == [], "No tweets were provided; engagement metrics are empty.")
    |> maybe_note(mentions == [], "No mentions were provided; sentiment sample is empty.")
    |> maybe_note(length(follower_snapshots) < 2, "Follower growth needs at least two snapshots.")
    |> Enum.reverse()
  end

  defp tweet_quality_notes(tweet, engagements) do
    []
    |> maybe_note(tweet.impressions == 0 and engagements > 0, "Engagements present with zero impressions.")
    |> maybe_note(tweet.text == "", "Tweet text is missing.")
    |> Enum.reverse()
  end

  defp maybe_note(notes, true, note), do: [note | notes]
  defp maybe_note(notes, false, _note), do: notes

  defp classify_sentiment(text) do
    tokens =
      text
      |> to_string()
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9#_ ]+/, " ")
      |> String.split()

    positive = Enum.count(tokens, &(&1 in @positive_words))
    negative = Enum.count(tokens, &(&1 in @negative_words))

    cond do
      positive > negative -> :positive
      negative > positive -> :negative
      true -> :neutral
    end
  end

  defp growth_trend(delta) when delta > 0, do: :up
  defp growth_trend(delta) when delta < 0, do: :down
  defp growth_trend(_delta), do: :flat

  defp alert_severity(:high_negative_sentiment), do: :critical
  defp alert_severity(_metric), do: :warning

  defp sum_metric(rows, key), do: Enum.reduce(rows, 0, &(&2 + non_negative_number(Map.get(&1, key, 0))))

  defp to_metric(value) when is_atom(value), do: value |> Atom.to_string() |> to_metric()

  defp to_metric(value) when is_binary(value) do
    case String.downcase(value) do
      "bookmarks" -> :bookmarks
      "engagement_rate" -> :engagement_rate
      "engagements" -> :engagements
      "impressions" -> :impressions
      "likes" -> :likes
      "profile_click_rate" -> :profile_click_rate
      "profile_clicks" -> :profile_clicks
      "quotes" -> :quotes
      "replies" -> :replies
      "retweets" -> :retweets
      "tweet_count" -> :tweet_count
      _ -> :engagements
    end
  end

  defp to_metric(_value), do: :engagements

  defp normalize_hashtag(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.trim_leading("#")
    |> String.downcase()
  end

  defp get_list(map, key) do
    case get_value(map, key, []) do
      value when is_list(value) -> value
      _ -> []
    end
  end

  defp get_map(map, key) do
    case get_value(map, key, %{}) do
      value when is_map(value) -> value
      _ -> %{}
    end
  end

  defp get_value(map, key, default) when is_map(map) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp get_value(_map, _key, default), do: default

  defp non_negative_number(value) when is_integer(value) and value >= 0, do: value
  defp non_negative_number(value) when is_float(value) and value >= 0, do: value

  defp non_negative_number(value) when is_binary(value) do
    case Float.parse(value) do
      {number, ""} when number >= 0 -> number
      _ -> 0
    end
  end

  defp non_negative_number(_value), do: 0

  defp percentage_or_number(value) do
    number = non_negative_number(value)
    if number > 1, do: number / 100, else: number
  end

  defp safe_ratio(_numerator, denominator) when denominator in [0, 0.0], do: 0.0
  defp safe_ratio(numerator, denominator), do: Float.round(numerator / denominator, 6)
end
