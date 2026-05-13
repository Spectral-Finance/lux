defmodule Lux.Integrations.Twitter.AnalyticsMonitor do
  @moduledoc """
  Deterministic analytics and monitoring engine for Twitter/X engagement data.

  The monitor accepts tweet metrics, follower snapshots, mentions, hashtags, thresholds,
  and custom metrics from an API client, stream, or export. It returns normalized metrics,
  aggregation records, sentiment, alerts, and a report payload without requiring live
  Twitter credentials in tests.
  """

  @default_period_days 28
  @positive_words ~w(great good love useful helpful strong bullish excellent thanks amazing win)
  @negative_words ~w(bad hate broken scam spam rug terrible weak angry disappointed problem)

  @doc """
  Builds the full analytics and monitoring report.
  """
  def run(input), do: analyze(input)

  def analyze(input) when is_map(input) do
    {:ok,
     %{
       account: string_value(input, :account, "twitter_account"),
       period_days: period_days(input),
       metrics_collection: collect_metrics(input),
       data_aggregation: aggregate_data(input),
       follower_growth: follower_growth(input),
       hashtag_performance: hashtag_performance(input),
       mention_sentiment: sentiment_analysis(input),
       real_time_monitoring: real_time_monitoring(input),
       alert_system: alert_system(input),
       custom_reporting: custom_report(input),
       automated_report: automated_report(input),
       performance_optimization: performance_optimization(input),
       action_plan: action_plan(input)
     }}
  end

  def analyze(_input), do: {:error, "Expected a map with Twitter analytics data"}

  @doc """
  Normalizes tweet rows into a metrics snapshot suitable for reports and alerts.
  """
  def collect_metrics(input) do
    tweets = normalized_tweets(input)
    period_days = period_days(input)

    impressions = sum(tweets, :impressions)
    engagements = sum(tweets, :engagements)
    likes = sum(tweets, :likes)
    reposts = sum(tweets, :reposts)
    replies = sum(tweets, :replies)
    quotes = sum(tweets, :quotes)
    bookmarks = sum(tweets, :bookmarks)
    clicks = sum(tweets, :url_clicks)

    %{
      tweet_count: length(tweets),
      period_days: period_days,
      collected_at: string_value(input, :collected_at, "deterministic-snapshot"),
      totals: %{
        impressions: impressions,
        engagements: engagements,
        likes: likes,
        reposts: reposts,
        replies: replies,
        quotes: quotes,
        bookmarks: bookmarks,
        url_clicks: clicks
      },
      rates: %{
        engagement_rate: ratio(engagements, impressions),
        reply_rate: ratio(replies, impressions),
        repost_rate: ratio(reposts, impressions),
        click_through_rate: ratio(clicks, impressions),
        average_daily_impressions: round_number(impressions / max(period_days, 1)),
        average_daily_engagements: round_number(engagements / max(period_days, 1))
      },
      tweets: tweets,
      top_tweets: tweets |> Enum.sort_by(& &1.engagement_rate, :desc) |> Enum.take(5),
      data_quality: data_quality(tweets)
    }
  end

  @doc """
  Aggregates normalized tweet, mention, and follower records into an in-memory store snapshot.
  """
  def aggregate_data(input) do
    tweets = normalized_tweets(input)
    mentions = normalized_mentions(input)
    followers = follower_snapshots(input)

    %{
      storage_snapshot: %{
        record_count: length(tweets) + length(mentions) + length(followers),
        tweet_records:
          Enum.map(tweets, &Map.take(&1, [:id, :published_at, :impressions, :engagements])),
        mention_records: Enum.map(mentions, &Map.take(&1, [:author, :sentiment, :created_at])),
        follower_records: followers,
        retention_days: int_value(input, :retention_days, 90)
      },
      by_day: aggregate_by(tweets, :published_at),
      by_hashtag: hashtag_performance(input).hashtags,
      query_index: %{
        tweet_ids: Enum.map(tweets, & &1.id),
        hashtags: tweets |> Enum.flat_map(& &1.hashtags) |> Enum.uniq() |> Enum.sort(),
        mention_authors: mentions |> Enum.map(& &1.author) |> Enum.uniq() |> Enum.sort()
      }
    }
  end

  @doc """
  Calculates follower growth from ordered follower snapshots.
  """
  def follower_growth(input) do
    snapshots = follower_snapshots(input)
    first = List.first(snapshots)
    last = List.last(snapshots)
    start_followers = number_value(first || %{}, :followers, 0)
    end_followers = number_value(last || %{}, :followers, 0)
    growth = end_followers - start_followers

    %{
      snapshot_count: length(snapshots),
      starting_followers: round_number(start_followers),
      ending_followers: round_number(end_followers),
      followers_gained: round_number(growth),
      follower_growth_rate: ratio(growth, start_followers),
      direction: growth_direction(growth),
      average_daily_growth: round_number(growth / max(period_days(input), 1))
    }
  end

  @doc """
  Ranks hashtags by usage, impressions, engagements, and engagement rate.
  """
  def hashtag_performance(input) do
    tweets = normalized_tweets(input)

    hashtags =
      tweets
      |> Enum.reduce(%{}, fn tweet, acc ->
        Enum.reduce(tweet.hashtags, acc, fn hashtag, inner_acc ->
          Map.update(
            inner_acc,
            hashtag,
            hashtag_row(tweet),
            &merge_hashtag_row(&1, tweet)
          )
        end)
      end)
      |> Map.new(fn {hashtag, row} ->
        {hashtag, Map.put(row, :engagement_rate, ratio(row.engagements, row.impressions))}
      end)

    %{
      hashtags: hashtags,
      top_hashtag: top_key_by(hashtags, :engagements),
      recommendations: hashtag_recommendations(hashtags)
    }
  end

  @doc """
  Performs lightweight deterministic mention sentiment analysis.
  """
  def sentiment_analysis(input) do
    mentions = normalized_mentions(input)
    counts = Enum.frequencies_by(mentions, & &1.sentiment)
    negative_count = Map.get(counts, "negative", 0)

    %{
      mention_count: length(mentions),
      sentiment_counts: counts,
      negative_sentiment_rate: ratio(negative_count, length(mentions)),
      top_negative_mentions:
        mentions
        |> Enum.filter(&(&1.sentiment == "negative"))
        |> Enum.sort_by(& &1.author_followers, :desc)
        |> Enum.take(5),
      recommendations: sentiment_recommendations(counts, length(mentions))
    }
  end

  @doc """
  Builds a real-time monitoring snapshot from the latest tweets and current velocity.
  """
  def real_time_monitoring(input) do
    tweets = input |> normalized_tweets() |> sort_by_date()
    recent = Enum.take(tweets, -min(length(tweets), 5))
    prior = Enum.take(tweets, max(length(tweets) - length(recent), 0))
    recent_rate = if recent == [], do: 0, else: average_raw(recent, :engagement_rate)
    prior_rate = if prior == [], do: recent_rate, else: average_raw(prior, :engagement_rate)

    %{
      latest_tweets: recent,
      engagement_trend: trend_direction(growth_rate(prior_rate, recent_rate)),
      current_velocity: %{
        impressions_per_day: collect_metrics(input).rates.average_daily_impressions,
        engagements_per_day: collect_metrics(input).rates.average_daily_engagements,
        follower_growth_per_day: follower_growth(input).average_daily_growth
      },
      monitoring_checks: [
        "refresh tweet metrics",
        "refresh mentions",
        "evaluate engagement thresholds",
        "publish automated report"
      ]
    }
  end

  @doc """
  Evaluates engagement, sentiment, and follower-growth thresholds.
  """
  def alert_system(input) do
    metrics = collect_metrics(input)
    sentiment = sentiment_analysis(input)
    followers = follower_growth(input)
    thresholds = map_value(input, :thresholds, %{})

    engagement_min = number_value(thresholds, :engagement_rate_min, 0.03)
    negative_max = number_value(thresholds, :negative_sentiment_rate_max, 0.25)
    follower_min = number_value(thresholds, :follower_growth_rate_min, 0.01)

    alerts =
      [
        metrics.rates.engagement_rate < engagement_min &&
          alert("engagement_rate_below_threshold", metrics.rates.engagement_rate, engagement_min),
        sentiment.negative_sentiment_rate > negative_max &&
          alert(
            "negative_sentiment_above_threshold",
            sentiment.negative_sentiment_rate,
            negative_max
          ),
        followers.follower_growth_rate < follower_min &&
          alert("follower_growth_below_threshold", followers.follower_growth_rate, follower_min)
      ]
      |> Enum.filter(& &1)

    %{
      thresholds: %{
        engagement_rate_min: engagement_min,
        negative_sentiment_rate_max: negative_max,
        follower_growth_rate_min: follower_min
      },
      alerts: alerts,
      status: if(alerts == [], do: "healthy", else: "attention_required")
    }
  end

  @doc """
  Creates customizable report sections and computes supported custom metrics.
  """
  def custom_report(input) do
    sections =
      case list_value(input, :report_sections) do
        [] -> ["metrics", "followers", "hashtags", "sentiment", "alerts"]
        values -> values
      end

    %{
      sections: sections,
      custom_metrics:
        input
        |> list_value(:custom_metrics)
        |> Enum.map(&compute_custom_metric(&1, input)),
      generated_reports: Enum.map(sections, &report_section(&1, input))
    }
  end

  @doc """
  Produces a dashboard-ready automated report.
  """
  def automated_report(input) do
    metrics = collect_metrics(input)
    followers = follower_growth(input)
    hashtags = hashtag_performance(input)
    sentiment = sentiment_analysis(input)
    alerts = alert_system(input)

    %{
      title: "#{string_value(input, :account, "Twitter account")} analytics report",
      summary: [
        "#{metrics.tweet_count} tweets generated #{metrics.totals.impressions} impressions",
        "Engagement rate #{metrics.rates.engagement_rate}; followers gained #{followers.followers_gained}",
        "Top hashtag #{hashtags.top_hashtag || "n/a"}; alert status #{alerts.status}"
      ],
      scorecard: %{
        engagement_rate: metrics.rates.engagement_rate,
        follower_growth_rate: followers.follower_growth_rate,
        negative_sentiment_rate: sentiment.negative_sentiment_rate,
        alert_count: length(alerts.alerts)
      },
      alerts: alerts.alerts,
      next_report_sections: [
        "Real-time metrics collection",
        "Data aggregation and storage",
        "Custom reporting",
        "Alert thresholds",
        "Sentiment monitoring",
        "Hashtag performance"
      ]
    }
  end

  @doc """
  Returns performance optimization recommendations tied to current bottlenecks.
  """
  def performance_optimization(input) do
    metrics = collect_metrics(input)
    sentiment = sentiment_analysis(input)
    hashtags = hashtag_performance(input)

    %{
      bottlenecks:
        [
          metrics.rates.engagement_rate < 0.03 && "low_engagement_rate",
          metrics.rates.click_through_rate < 0.005 && "low_click_through_rate",
          sentiment.negative_sentiment_rate > 0.25 && "negative_mentions",
          is_nil(hashtags.top_hashtag) && "missing_hashtag_signal"
        ]
        |> Enum.filter(& &1),
      recommendations: optimization_recommendations(metrics, sentiment, hashtags)
    }
  end

  defp action_plan(input) do
    alerts = alert_system(input)
    hashtags = hashtag_performance(input)

    [
      "Monitor #{collect_metrics(input).tweet_count} normalized tweet records each reporting cycle",
      "Prioritize #{hashtags.top_hashtag || "the highest-engagement topic"} in the next content batch",
      "Resolve #{length(alerts.alerts)} active threshold alerts",
      "Publish the automated report with sections: #{Enum.join(custom_report(input).sections, ", ")}"
    ]
  end

  defp normalized_tweets(input) do
    input
    |> list_value(:tweets)
    |> Enum.map(&normalize_tweet/1)
  end

  defp normalize_tweet(tweet) when is_map(tweet) do
    impressions = int_value(tweet, :impressions, 0)
    likes = int_value(tweet, :likes, 0)
    reposts = int_value(tweet, :reposts, int_value(tweet, :retweets, 0))
    replies = int_value(tweet, :replies, 0)
    quotes = int_value(tweet, :quotes, 0)
    bookmarks = int_value(tweet, :bookmarks, 0)
    clicks = int_value(tweet, :url_clicks, 0)
    engagements = likes + reposts + replies + quotes + bookmarks + clicks

    %{
      id: string_value(tweet, :id, "tweet-#{:erlang.phash2(tweet)}"),
      text: string_value(tweet, :text, ""),
      published_at: value(tweet, :published_at),
      impressions: impressions,
      engagements: engagements,
      likes: likes,
      reposts: reposts,
      replies: replies,
      quotes: quotes,
      bookmarks: bookmarks,
      url_clicks: clicks,
      hashtags: hashtags(tweet),
      engagement_rate: ratio(engagements, impressions)
    }
  end

  defp normalize_tweet(_tweet), do: normalize_tweet(%{})

  defp normalized_mentions(input) do
    input
    |> list_value(:mentions)
    |> Enum.map(&normalize_mention/1)
  end

  defp normalize_mention(mention) when is_map(mention) do
    text = string_value(mention, :text, "")

    %{
      author: string_value(mention, :author, "unknown"),
      text: text,
      created_at: value(mention, :created_at),
      author_followers: int_value(mention, :author_followers, 0),
      sentiment: classify_sentiment(text),
      score: sentiment_score(text)
    }
  end

  defp normalize_mention(_mention), do: normalize_mention(%{})

  defp follower_snapshots(input) do
    input
    |> list_value(:follower_snapshots)
    |> Enum.map(fn snapshot ->
      %{
        date: value(snapshot, :date),
        followers: int_value(snapshot, :followers, 0),
        following: int_value(snapshot, :following, 0),
        tweet_count: int_value(snapshot, :tweet_count, int_value(snapshot, :tweets, 0))
      }
    end)
    |> Enum.sort_by(&to_string(&1.date || ""))
  end

  defp data_quality([]), do: %{status: "missing", notes: ["No tweets supplied"]}

  defp data_quality(tweets) do
    missing_impressions = Enum.count(tweets, &(&1.impressions == 0))

    %{
      status: if(missing_impressions == 0, do: "complete", else: "partial"),
      notes:
        [
          missing_impressions > 0 && "#{missing_impressions} tweets missing impressions"
        ]
        |> Enum.filter(& &1)
    }
  end

  defp aggregate_by(tweets, key) do
    tweets
    |> Enum.group_by(&to_string(Map.get(&1, key) || "unknown"))
    |> Map.new(fn {bucket, rows} ->
      {bucket,
       %{
         tweets: length(rows),
         impressions: sum(rows, :impressions),
         engagements: sum(rows, :engagements),
         engagement_rate: ratio(sum(rows, :engagements), sum(rows, :impressions))
       }}
    end)
  end

  defp hashtag_row(tweet) do
    %{
      uses: 1,
      impressions: tweet.impressions,
      engagements: tweet.engagements
    }
  end

  defp merge_hashtag_row(row, tweet) do
    %{
      uses: row.uses + 1,
      impressions: row.impressions + tweet.impressions,
      engagements: row.engagements + tweet.engagements
    }
  end

  defp hashtag_recommendations(hashtags) when map_size(hashtags) == 0 do
    ["Add tracked hashtags to tweets before evaluating hashtag performance"]
  end

  defp hashtag_recommendations(hashtags) do
    top = top_key_by(hashtags, :engagements)

    [
      "Build the next campaign around #{top}",
      "Compare hashtag engagement rate before scaling volume"
    ]
  end

  defp sentiment_recommendations(_counts, 0), do: ["Add mentions to enable sentiment monitoring"]

  defp sentiment_recommendations(counts, total) do
    negative_rate = ratio(Map.get(counts, "negative", 0), total)

    [
      negative_rate > 0.25 && "Route negative high-reach mentions to manual review",
      Map.get(counts, "positive", 0) > 0 && "Reuse positive mention language in campaign copy",
      "Track sentiment by campaign hashtag"
    ]
    |> Enum.filter(& &1)
  end

  defp optimization_recommendations(metrics, sentiment, hashtags) do
    [
      metrics.rates.engagement_rate < 0.03 && "Test stronger hooks and clearer calls to reply",
      metrics.rates.click_through_rate < 0.005 &&
        "Move links into follow-up tweets or pinned replies",
      sentiment.negative_sentiment_rate > 0.25 &&
        "Pause promotion until negative mention drivers are resolved",
      hashtags.top_hashtag &&
        "Increase cadence for #{hashtags.top_hashtag} while monitoring saturation"
    ]
    |> Enum.filter(& &1)
    |> case do
      [] -> ["Scale current posting pattern while keeping threshold alerts active"]
      recommendations -> recommendations
    end
  end

  defp compute_custom_metric(metric, input) when is_map(metric) do
    name = string_value(metric, :name, "custom_metric")
    formula = string_value(metric, :formula, "")
    metrics = collect_metrics(input)

    value =
      case formula do
        "engagements_per_tweet" ->
          ratio(metrics.totals.engagements, max(metrics.tweet_count, 1))

        "reposts_per_1k_impressions" ->
          rate_per_1k(metrics.totals.reposts, metrics.totals.impressions)

        "clicks_per_1k_impressions" ->
          rate_per_1k(metrics.totals.url_clicks, metrics.totals.impressions)

        _ ->
          nil
      end

    %{name: name, formula: formula, value: value}
  end

  defp compute_custom_metric(metric, _input),
    do: %{name: to_string(metric), formula: "", value: nil}

  defp report_section("metrics", input),
    do: %{section: "metrics", data: collect_metrics(input).rates}

  defp report_section("followers", input),
    do: %{section: "followers", data: follower_growth(input)}

  defp report_section("hashtags", input),
    do: %{section: "hashtags", data: hashtag_performance(input)}

  defp report_section("sentiment", input),
    do: %{section: "sentiment", data: sentiment_analysis(input)}

  defp report_section("alerts", input), do: %{section: "alerts", data: alert_system(input)}
  defp report_section(section, _input), do: %{section: section, data: %{}}

  defp alert(type, current, threshold) do
    %{type: type, current: current, threshold: threshold, severity: alert_severity(type)}
  end

  defp alert_severity("negative_sentiment_above_threshold"), do: "high"
  defp alert_severity(_type), do: "medium"

  defp hashtags(tweet) do
    explicit = list_value(tweet, :hashtags)
    text = string_value(tweet, :text, "")

    extracted =
      ~r/(?:^|\s)#([A-Za-z0-9_]+)/
      |> Regex.scan(text)
      |> Enum.map(fn [_full, tag] -> String.downcase(tag) end)

    (explicit ++ extracted)
    |> Enum.map(&(&1 |> to_string() |> String.trim_leading("#") |> String.downcase()))
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp classify_sentiment(text) do
    score = sentiment_score(text)

    cond do
      score > 0 -> "positive"
      score < 0 -> "negative"
      true -> "neutral"
    end
  end

  defp sentiment_score(text) do
    words =
      text
      |> String.downcase()
      |> String.split(~r/[^a-z0-9]+/, trim: true)

    positive = Enum.count(words, &(&1 in @positive_words))
    negative = Enum.count(words, &(&1 in @negative_words))
    positive - negative
  end

  defp sort_by_date(rows), do: Enum.sort_by(rows, &to_string(&1.published_at || ""))

  defp growth_direction(value) when value > 0, do: "up"
  defp growth_direction(value) when value < 0, do: "down"
  defp growth_direction(_value), do: "flat"

  defp trend_direction(rate) when rate > 0.1, do: "up"
  defp trend_direction(rate) when rate < -0.1, do: "down"
  defp trend_direction(_rate), do: "flat"

  defp growth_rate(0, current) when current > 0, do: 1
  defp growth_rate(0, _current), do: 0
  defp growth_rate(previous, current), do: (current - previous) / previous

  defp rate_per_1k(value, base), do: round_number(ratio(value, base) * 1000)

  defp ratio(_value, base) when base in [0, 0.0], do: 0
  defp ratio(value, base), do: round_number(value / base)

  defp average_raw([], _key), do: 0
  defp average_raw(values, key), do: sum(values, key) / length(values)

  defp sum(values, key), do: values |> Enum.map(&Map.get(&1, key, 0)) |> Enum.sum()

  defp top_key_by(values, _key) when map_size(values) == 0, do: nil

  defp top_key_by(values, key),
    do: values |> Enum.max_by(fn {_name, row} -> Map.get(row, key, 0) end) |> elem(0)

  defp period_days(input), do: max(int_value(input, :period_days, @default_period_days), 1)

  defp list_value(input, key) do
    case value(input, key, []) do
      values when is_list(values) -> values
      value when is_binary(value) -> [value]
      _ -> []
    end
  end

  defp map_value(input, key, default) do
    case value(input, key, default) do
      value when is_map(value) -> value
      _ -> default
    end
  end

  defp string_value(input, key, default) do
    case value(input, key, default) do
      value when is_binary(value) -> value
      value when is_atom(value) -> Atom.to_string(value)
      value when is_number(value) -> to_string(value)
      _ -> default
    end
  end

  defp int_value(input, key, default) do
    input
    |> number_value(key, default)
    |> round()
  end

  defp number_value(input, key, default) do
    case value(input, key, default) do
      value when is_integer(value) ->
        value

      value when is_float(value) ->
        value

      value when is_binary(value) ->
        case Float.parse(value) do
          {number, _rest} -> number
          :error -> default
        end

      _ ->
        default
    end
  end

  defp value(input, key, default \\ nil)

  defp value(input, key, default) when is_map(input) do
    Map.get(input, key, Map.get(input, to_string(key), default))
  end

  defp value(_input, _key, default), do: default

  defp round_number(value, precision \\ 4)
  defp round_number(value, _precision) when is_integer(value), do: value
  defp round_number(value, precision) when is_float(value), do: Float.round(value, precision)
  defp round_number(value, _precision), do: value
end
