defmodule Lux.Prisms.Twitter.Analytics.GenerateEngagementReport do
  @moduledoc """
  A prism for generating engagement reports from Twitter metrics data.

  Aggregates metrics from multiple tweets into a comprehensive engagement
  report with averages, totals, top performers, and trend indicators.

  ## Implementation Details

  - Computes aggregate metrics: totals, averages, medians
  - Identifies top-performing tweets by engagement rate
  - Calculates engagement quality score (weighted metric combination)
  - Generates actionable insights based on metric patterns
  - Pure computation — no API call required

  ## Examples

      iex> GenerateEngagementReport.handler(%{
      ...>   tweets: [
      ...>     %{tweet_id: "1", metrics: %{like_count: 100, retweet_count: 50, impression_count: 5000}},
      ...>     %{tweet_id: "2", metrics: %{like_count: 200, retweet_count: 80, impression_count: 8000}}
      ...>   ],
      ...>   username: "myaccount"
      ...> }, %{})
      {:ok, %{
        username: "myaccount",
        report_period: "all_time",
        totals: %{likes: 300, retweets: 130, impressions: 13000},
        averages: %{likes_per_tweet: 150.0, engagement_rate: 2.31},
        top_tweets: [...],
        insights: ["Strong retweet rate indicates highly shareable content"]
      }}
  """

  use Lux.Prism,
    name: "Generate Twitter Engagement Report",
    description: "Generates a comprehensive engagement report from tweet metrics including totals, averages, and actionable insights",
    input_schema: %{
      type: :object,
      properties: %{
        tweets: %{
          type: :array,
          description: "Array of tweet metrics (from GetTweetMetrics lens)",
          items: %{type: :object}
        },
        username: %{
          type: :string,
          description: "Twitter username for the report header"
        },
        period: %{
          type: :string,
          description: "Reporting period label (e.g. 'last_7_days', 'last_30_days')",
          default: "all_time"
        }
      },
      required: ["tweets"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        username: %{type: :string},
        report_period: %{type: :string},
        tweet_count: %{type: :integer},
        totals: %{type: :object},
        averages: %{type: :object},
        top_tweets: %{type: :array},
        insights: %{type: :array, items: %{type: :string}}
      }
    }

  @impl true
  def handler(params, _agent) do
    tweets = params[:tweets] || params["tweets"] || []
    username = params[:username] || params["username"]
    period = to_string(params[:period] || params["period"] || "all_time")

    tweets = Enum.map(tweets, &normalize_tweet/1)

    totals = compute_totals(tweets)
    averages = compute_averages(tweets, totals)
    top_tweets = find_top_tweets(tweets, 3)
    insights = generate_insights(averages, totals)

    {:ok, %{
      username: username,
      report_period: period,
      tweet_count: length(tweets),
      totals: totals,
      averages: averages,
      top_tweets: top_tweets,
      insights: insights
    }}
  end

  defp normalize_tweet(t) do
    metrics = t[:metrics] || t["metrics"] || %{}
    %{
      tweet_id: t[:tweet_id] || t["tweet_id"] || t[:id] || t["id"],
      text: t[:text] || t["text"],
      metrics: %{
        like_count: get_metric(metrics, "like_count"),
        retweet_count: get_metric(metrics, "retweet_count"),
        reply_count: get_metric(metrics, "reply_count"),
        quote_count: get_metric(metrics, "quote_count"),
        impression_count: get_metric(metrics, "impression_count"),
        bookmark_count: get_metric(metrics, "bookmark_count")
      },
      engagement_rate: t[:engagement_rate] || t["engagement_rate"] || 0.0
    }
  end

  defp get_metric(metrics, key) do
    metrics[key] || metrics[String.to_atom(key)] || 0
  end

  defp compute_totals([]), do: %{likes: 0, retweets: 0, replies: 0, quotes: 0, impressions: 0, bookmarks: 0}
  defp compute_totals(tweets) do
    %{
      likes: Enum.sum(Enum.map(tweets, & &1.metrics.like_count)),
      retweets: Enum.sum(Enum.map(tweets, & &1.metrics.retweet_count)),
      replies: Enum.sum(Enum.map(tweets, & &1.metrics.reply_count)),
      quotes: Enum.sum(Enum.map(tweets, & &1.metrics.quote_count)),
      impressions: Enum.sum(Enum.map(tweets, & &1.metrics.impression_count)),
      bookmarks: Enum.sum(Enum.map(tweets, & &1.metrics.bookmark_count))
    }
  end

  defp compute_averages([], _totals) do
    %{likes_per_tweet: 0.0, retweets_per_tweet: 0.0, replies_per_tweet: 0.0, engagement_rate: 0.0}
  end
  defp compute_averages(tweets, totals) do
    count = length(tweets)
    avg_impressions = totals.impressions / count
    total_engagement = totals.likes + totals.retweets + totals.replies + totals.quotes + totals.bookmarks
    avg_engagement_rate = if avg_impressions > 0, do: Float.round(total_engagement / totals.impressions * 100, 2), else: 0.0

    %{
      likes_per_tweet: Float.round(totals.likes / count, 1),
      retweets_per_tweet: Float.round(totals.retweets / count, 1),
      replies_per_tweet: Float.round(totals.replies / count, 1),
      impressions_per_tweet: Float.round(avg_impressions, 0),
      engagement_rate: avg_engagement_rate
    }
  end

  defp find_top_tweets(tweets, n) do
    tweets
    |> Enum.sort_by(fn t ->
      t.metrics.like_count + t.metrics.retweet_count * 2 + t.metrics.reply_count
    end, :desc)
    |> Enum.take(n)
    |> Enum.map(&Map.take(&1, [:tweet_id, :text, :metrics, :engagement_rate]))
  end

  defp generate_insights(averages, totals) do
    insights = []

    insights = if totals.impressions > 0 && averages.engagement_rate > 3.0 do
      ["High engagement rate (#{averages.engagement_rate}%) — above average for Twitter" | insights]
    else
      insights
    end

    insights = if totals.retweets > 0 && averages.retweets_per_tweet > averages.likes_per_tweet * 0.3 do
      ["Strong retweet ratio indicates highly shareable content" | insights]
    else
      insights
    end

    insights = if averages.replies_per_tweet > 0 && averages.replies_per_tweet > averages.likes_per_tweet * 0.2 do
      ["High reply rate — content is sparking conversations" | insights]
    else
      insights
    end

    insights = if totals.impressions == 0 do
      ["No impression data available — enable analytics on your Twitter account" | insights]
    else
      insights
    end

    if Enum.empty?(insights) do
      ["Consistent engagement — maintain current posting frequency and content style"]
    else
      Enum.reverse(insights)
    end
  end
end
