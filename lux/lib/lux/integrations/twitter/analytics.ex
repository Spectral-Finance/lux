defmodule Lux.Integrations.Twitter.Analytics do
  @moduledoc """
  Twitter/X analytics helpers for engagement monitoring and reporting.

  The helpers are transport-neutral: callers can collect raw tweet, mention,
  hashtag, and follower snapshots from any API client, then use this module to
  aggregate metrics, evaluate alert rules, and generate report payloads.
  """

  @engagement_keys [:like_count, :reply_count, :retweet_count, :quote_count, :bookmark_count]

  @doc """
  Normalizes engagement metrics for a single tweet-like record.
  """
  @spec engagement_metrics(map()) :: map()
  def engagement_metrics(tweet) when is_map(tweet) do
    metrics =
      Enum.reduce(@engagement_keys, %{}, fn key, acc ->
        Map.put(acc, key, int_value(tweet, key))
      end)

    total_engagements =
      metrics
      |> Map.values()
      |> Enum.sum()

    impression_count = int_value(tweet, :impression_count)

    metrics
    |> Map.merge(%{
      tweet_id: value(tweet, :id),
      impression_count: impression_count,
      total_engagements: total_engagements,
      engagement_rate: safe_ratio(total_engagements, impression_count)
    })
  end

  @doc """
  Aggregates engagement metrics across a list of tweets.
  """
  @spec aggregate_engagement([map()]) :: map()
  def aggregate_engagement(tweets) when is_list(tweets) do
    metrics = Enum.map(tweets, &engagement_metrics/1)

    totals =
      Enum.reduce(metrics, empty_totals(), fn metric, acc ->
        %{
          like_count: acc.like_count + metric.like_count,
          reply_count: acc.reply_count + metric.reply_count,
          retweet_count: acc.retweet_count + metric.retweet_count,
          quote_count: acc.quote_count + metric.quote_count,
          bookmark_count: acc.bookmark_count + metric.bookmark_count,
          impression_count: acc.impression_count + metric.impression_count,
          total_engagements: acc.total_engagements + metric.total_engagements
        }
      end)

    %{
      tweet_count: length(tweets),
      totals: totals,
      averages: %{
        engagement_rate: average(metrics, :engagement_rate),
        engagements_per_tweet: safe_ratio(totals.total_engagements, length(tweets))
      },
      top_tweets: top_by(metrics, :total_engagements, 5)
    }
  end

  @doc """
  Calculates follower-growth deltas from ordered or unordered snapshots.
  """
  @spec follower_growth([map()]) :: map()
  def follower_growth(snapshots) when is_list(snapshots) do
    sorted = Enum.sort_by(snapshots, &(value(&1, :captured_at) || ""))
    first = List.first(sorted) || %{}
    last = List.last(sorted) || %{}
    start_count = int_value(first, :follower_count)
    end_count = int_value(last, :follower_count)
    delta = end_count - start_count

    %{
      start_count: start_count,
      end_count: end_count,
      delta: delta,
      growth_rate: safe_ratio(delta, start_count),
      sample_count: length(sorted),
      start_at: value(first, :captured_at),
      end_at: value(last, :captured_at)
    }
  end

  @doc """
  Aggregates hashtag performance from tweet text and engagement metrics.
  """
  @spec hashtag_performance([map()]) :: [map()]
  def hashtag_performance(tweets) when is_list(tweets) do
    tweets
    |> Enum.flat_map(fn tweet ->
      engagement = engagement_metrics(tweet)

      tweet
      |> value(:text)
      |> extract_hashtags()
      |> Enum.map(&{&1, engagement.total_engagements})
    end)
    |> Enum.reduce(%{}, fn {hashtag, engagements}, acc ->
      Map.update(acc, hashtag, %{hashtag: hashtag, count: 1, total_engagements: engagements}, fn existing ->
        %{existing | count: existing.count + 1, total_engagements: existing.total_engagements + engagements}
      end)
    end)
    |> Map.values()
    |> Enum.map(fn item -> Map.put(item, :engagements_per_post, safe_ratio(item.total_engagements, item.count)) end)
    |> Enum.sort_by(& &1.total_engagements, :desc)
  end

  @doc """
  Summarizes mention sentiment from labeled or scored mention records.
  """
  @spec sentiment_rollup([map()]) :: map()
  def sentiment_rollup(mentions) when is_list(mentions) do
    counts =
      Enum.reduce(mentions, %{positive: 0, neutral: 0, negative: 0}, fn mention, acc ->
        sentiment = normalize_sentiment(value(mention, :sentiment) || value(mention, :sentiment_score))
        Map.update!(acc, sentiment, &(&1 + 1))
      end)

    total = length(mentions)

    %{
      total_mentions: total,
      counts: counts,
      positive_ratio: safe_ratio(counts.positive, total),
      negative_ratio: safe_ratio(counts.negative, total)
    }
  end

  @doc """
  Evaluates alert rules against a metrics map.
  """
  @spec evaluate_alerts(map(), [map()]) :: [map()]
  def evaluate_alerts(metrics, rules) when is_map(metrics) and is_list(rules) do
    rules
    |> Enum.filter(&triggered?(metrics, &1))
    |> Enum.map(fn rule ->
      metric = value(rule, :metric)

      %{
        metric: metric,
        operator: value(rule, :operator) || :>=,
        threshold: value(rule, :threshold),
        value: metric_value(metrics, metric),
        severity: value(rule, :severity) || :info,
        message: value(rule, :message) || "#{metric} crossed threshold"
      }
    end)
  end

  @doc """
  Builds a report payload from collected Twitter analytics data.
  """
  @spec report(map(), map()) :: map()
  def report(snapshot, opts \\ %{}) when is_map(snapshot) do
    tweets = value(snapshot, :tweets) || []
    mentions = value(snapshot, :mentions) || []
    follower_snapshots = value(snapshot, :follower_snapshots) || []
    engagement = aggregate_engagement(tweets)
    follower_growth = follower_growth(follower_snapshots)
    sentiment = sentiment_rollup(mentions)

    %{
      generated_at: value(opts, :generated_at) || DateTime.utc_now(),
      account: value(snapshot, :account),
      engagement: engagement,
      follower_growth: follower_growth,
      hashtags: hashtag_performance(tweets),
      sentiment: sentiment,
      alerts: evaluate_alerts(flatten_report_metrics(engagement, follower_growth, sentiment), value(opts, :alert_rules) || [])
    }
  end

  defp empty_totals do
    %{
      like_count: 0,
      reply_count: 0,
      retweet_count: 0,
      quote_count: 0,
      bookmark_count: 0,
      impression_count: 0,
      total_engagements: 0
    }
  end

  defp extract_hashtags(nil), do: []

  defp extract_hashtags(text) when is_binary(text) do
    ~r/(?:^|\s)#([[:alnum:]_]+)/u
    |> Regex.scan(text, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&String.downcase/1)
  end

  defp normalize_sentiment(sentiment) when sentiment in [:positive, "positive"], do: :positive
  defp normalize_sentiment(sentiment) when sentiment in [:negative, "negative"], do: :negative
  defp normalize_sentiment(score) when is_number(score) and score > 0, do: :positive
  defp normalize_sentiment(score) when is_number(score) and score < 0, do: :negative
  defp normalize_sentiment(_sentiment), do: :neutral

  defp triggered?(metrics, rule) do
    value = metric_value(metrics, value(rule, :metric))
    threshold = value(rule, :threshold)

    case value(rule, :operator) || :>= do
      :> -> value > threshold
      :>= -> value >= threshold
      :< -> value < threshold
      :<= -> value <= threshold
      :== -> value == threshold
      ">" -> value > threshold
      ">=" -> value >= threshold
      "<" -> value < threshold
      "<=" -> value <= threshold
      "==" -> value == threshold
      _operator -> false
    end
  end

  defp flatten_report_metrics(engagement, follower_growth, sentiment) do
    %{
      total_engagements: engagement.totals.total_engagements,
      engagement_rate: engagement.averages.engagement_rate,
      follower_delta: follower_growth.delta,
      follower_growth_rate: follower_growth.growth_rate,
      negative_ratio: sentiment.negative_ratio,
      positive_ratio: sentiment.positive_ratio
    }
  end

  defp metric_value(metrics, metric), do: value(metrics, metric) || 0

  defp top_by(items, key, limit) do
    items
    |> Enum.sort_by(&Map.get(&1, key, 0), :desc)
    |> Enum.take(limit)
  end

  defp average([], _key), do: 0.0

  defp average(items, key) do
    items
    |> Enum.map(&Map.get(&1, key, 0.0))
    |> Enum.sum()
    |> safe_ratio(length(items))
  end

  defp safe_ratio(_numerator, 0), do: 0.0
  defp safe_ratio(numerator, denominator), do: numerator / denominator

  defp int_value(map, key) do
    case value(map, key) do
      value when is_integer(value) -> value
      value when is_float(value) -> round(value)
      value when is_binary(value) ->
        case Integer.parse(value) do
          {parsed, _rest} -> parsed
          :error -> 0
        end

      _value ->
        0
    end
  end

  defp value(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp value(_map, _key), do: nil
end
