defmodule Lux.Integrations.Twitter.Analytics do
  @moduledoc """
  Transport-neutral Twitter/X analytics helpers.

  The functions in this module operate on already-collected tweet, follower,
  mention, and metric events. They do not call Twitter/X APIs or require
  credentials, which keeps them reusable across bearer-token, OAuth, webhook, or
  exported-data transports.
  """

  @positive_words ~w(great excellent bullish love thanks win wins growth happy strong amazing)
  @negative_words ~w(bad terrible bearish hate issue issues bug broken down angry poor fail)

  @doc """
  Builds a complete analytics report from normalized social events.
  """
  def build_report(input) when is_map(input) do
    tweets = field(input, :tweets, [])
    followers = field(input, :followers, [])
    mentions = field(input, :mentions, [])
    thresholds = field(input, :thresholds, %{})

    engagement = aggregate_engagement(tweets)
    follower_growth = follower_growth(followers)
    hashtags = hashtag_performance(tweets)
    sentiment = mention_sentiment(mentions)

    alerts =
      evaluate_alerts(
        %{
          engagement: engagement,
          follower_growth: follower_growth,
          hashtags: hashtags,
          sentiment: sentiment
        },
        thresholds
      )

    %{
      generated_at: field(input, :generated_at, "deterministic"),
      engagement: engagement,
      follower_growth: follower_growth,
      hashtags: hashtags,
      sentiment: sentiment,
      alerts: alerts,
      charts: build_chart_payloads(tweets, followers, hashtags),
      summary: summarize_report(engagement, follower_growth, sentiment, alerts)
    }
  end

  @doc """
  Aggregates tweet-level engagement metrics.
  """
  def aggregate_engagement(tweets) when is_list(tweets) do
    totals =
      Enum.reduce(
        tweets,
        %{likes: 0, replies: 0, reposts: 0, quotes: 0, impressions: 0},
        fn tweet, acc ->
          metrics = field(tweet, :metrics, %{})

          %{
            likes: acc.likes + metric(metrics, :likes),
            replies: acc.replies + metric(metrics, :replies),
            reposts: acc.reposts + metric(metrics, :reposts),
            quotes: acc.quotes + metric(metrics, :quotes),
            impressions: acc.impressions + metric(metrics, :impressions)
          }
        end
      )

    interactions = totals.likes + totals.replies + totals.reposts + totals.quotes

    %{
      tweet_count: length(tweets),
      totals: Map.put(totals, :interactions, interactions),
      engagement_rate: safe_rate(interactions, totals.impressions),
      top_tweet: top_tweet(tweets)
    }
  end

  @doc """
  Calculates follower growth from chronological follower-count samples.
  """
  def follower_growth(samples) when is_list(samples) do
    sorted = Enum.sort_by(samples, &field(&1, :captured_at, ""))
    first = List.first(sorted) || %{followers: 0}
    last = List.last(sorted) || %{followers: 0}
    delta = field(last, :followers, 0) - field(first, :followers, 0)

    %{
      start_followers: field(first, :followers, 0),
      end_followers: field(last, :followers, 0),
      delta: delta,
      growth_rate: safe_rate(delta, max(field(first, :followers, 0), 1)),
      samples: length(sorted)
    }
  end

  @doc """
  Aggregates hashtag usage and engagement.
  """
  def hashtag_performance(tweets) when is_list(tweets) do
    tweets
    |> Enum.flat_map(fn tweet ->
      tweet
      |> field(:hashtags, [])
      |> Enum.map(&{String.downcase(&1), tweet})
    end)
    |> Enum.group_by(fn {tag, _tweet} -> tag end, fn {_tag, tweet} -> tweet end)
    |> Enum.map(fn {tag, tagged_tweets} ->
      engagement = aggregate_engagement(tagged_tweets)

      %{
        hashtag: tag,
        tweet_count: length(tagged_tweets),
        interactions: engagement.totals.interactions,
        impressions: engagement.totals.impressions,
        engagement_rate: engagement.engagement_rate
      }
    end)
    |> Enum.sort_by(&{-&1.interactions, &1.hashtag})
  end

  @doc """
  Produces a deterministic sentiment rollup for mentions.
  """
  def mention_sentiment(mentions) when is_list(mentions) do
    classifications = Enum.map(mentions, &classify_text(field(&1, :text, "")))
    counts = Enum.frequencies(classifications)

    %{
      mention_count: length(mentions),
      positive: Map.get(counts, :positive, 0),
      neutral: Map.get(counts, :neutral, 0),
      negative: Map.get(counts, :negative, 0),
      positive_rate: safe_rate(Map.get(counts, :positive, 0), max(length(mentions), 1)),
      negative_rate: safe_rate(Map.get(counts, :negative, 0), max(length(mentions), 1))
    }
  end

  @doc """
  Evaluates alert thresholds for engagement, growth, sentiment, and hashtags.
  """
  def evaluate_alerts(report_sections, thresholds) do
    [
      maybe_alert(
        :low_engagement_rate,
        report_sections.engagement.engagement_rate,
        field(thresholds, :min_engagement_rate),
        :below
      ),
      maybe_alert(
        :negative_follower_growth,
        report_sections.follower_growth.delta,
        field(thresholds, :min_follower_delta, 0),
        :below
      ),
      maybe_alert(
        :high_negative_sentiment,
        report_sections.sentiment.negative_rate,
        field(thresholds, :max_negative_sentiment),
        :above
      ),
      maybe_hashtag_alert(
        report_sections.hashtags,
        field(thresholds, :min_hashtag_interactions)
      )
    ]
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Builds chart-friendly payloads for dashboards and reports.
  """
  def build_chart_payloads(tweets, follower_samples, hashtags) do
    %{
      engagement_by_tweet:
        Enum.map(tweets, fn tweet ->
          metrics = field(tweet, :metrics, %{})

          %{
            id: field(tweet, :id),
            label: field(tweet, :label, field(tweet, :id)),
            interactions:
              metric(metrics, :likes) + metric(metrics, :replies) + metric(metrics, :reposts) +
                metric(metrics, :quotes)
          }
        end),
      follower_growth:
        follower_samples
        |> Enum.sort_by(&field(&1, :captured_at, ""))
        |> Enum.map(&%{captured_at: field(&1, :captured_at), followers: field(&1, :followers, 0)}),
      hashtag_interactions:
        Enum.map(hashtags, &%{hashtag: &1.hashtag, interactions: &1.interactions})
    }
  end

  defp metric(metrics, key), do: Map.get(metrics, key, Map.get(metrics, Atom.to_string(key), 0))

  defp field(map, key, default \\ nil) when is_map(map) do
    Map.get(map, key, Map.get(map, Atom.to_string(key), default))
  end

  defp safe_rate(_numerator, 0), do: 0.0
  defp safe_rate(numerator, denominator), do: Float.round(numerator / denominator, 4)

  defp top_tweet([]), do: nil

  defp top_tweet(tweets) do
    tweets
    |> Enum.max_by(fn tweet ->
      metrics = field(tweet, :metrics, %{})

      metric(metrics, :likes) + metric(metrics, :replies) + metric(metrics, :reposts) +
        metric(metrics, :quotes)
    end)
    |> then(&%{id: field(&1, :id), label: field(&1, :label)})
  end

  defp classify_text(text) do
    tokens =
      text
      |> String.downcase()
      |> String.split(~r/[^a-z0-9_]+/, trim: true)

    positive = Enum.count(tokens, &(&1 in @positive_words))
    negative = Enum.count(tokens, &(&1 in @negative_words))

    cond do
      positive > negative -> :positive
      negative > positive -> :negative
      true -> :neutral
    end
  end

  defp maybe_alert(_type, _actual, nil, _direction), do: nil

  defp maybe_alert(type, actual, threshold, :below) when actual < threshold do
    %{type: type, actual: actual, threshold: threshold, severity: :warning}
  end

  defp maybe_alert(type, actual, threshold, :above) when actual > threshold do
    %{type: type, actual: actual, threshold: threshold, severity: :warning}
  end

  defp maybe_alert(_type, _actual, _threshold, _direction), do: nil

  defp maybe_hashtag_alert(_hashtags, nil), do: nil

  defp maybe_hashtag_alert(hashtags, threshold) do
    top = List.first(hashtags)

    if top && top.interactions < threshold do
      %{
        type: :weak_hashtag_performance,
        actual: top.interactions,
        threshold: threshold,
        severity: :info
      }
    end
  end

  defp summarize_report(engagement, follower_growth, sentiment, alerts) do
    %{
      headline:
        "Tracked #{engagement.tweet_count} tweets with #{engagement.totals.interactions} interactions and #{follower_growth.delta} net followers.",
      risk_level: if(alerts == [], do: :normal, else: :watch),
      sentiment_mix: %{
        positive: sentiment.positive,
        neutral: sentiment.neutral,
        negative: sentiment.negative
      }
    }
  end
end
