defmodule Lux.Lenses.Twitter.EngagementMetricsLens do
  @moduledoc """
  Lens for collecting Twitter/X engagement metrics.

  Retrieves comprehensive engagement data including likes, retweets, replies,
  impressions, bookmarks, and engagement rate calculations for specific tweets
  or user timelines.

  ## Example

      iex> Lux.Lenses.Twitter.EngagementMetricsLens.focus(%{tweet_ids: ["12345", "67890"]})
      {:ok, %{metrics: [...], total_engagement: 1234}}
  """

  use Lux.Lens,
    name: "Twitter Engagement Metrics",
    description: "Collects Twitter engagement metrics including likes, retweets, replies, impressions, and engagement rates",
    url: "https://api.twitter.com/2/tweets",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :api_key,
      key: &System.get_env("TWITTER_BEARER_TOKEN")
    },
    schema: %{
      type: :object,
      properties: %{
        tweet_ids: %{
          type: :array,
          items: %{type: :string},
          description: "List of tweet IDs to fetch engagement metrics for"
        },
        user_id: %{
          type: :string,
          description: "Twitter user ID to fetch metrics for all their tweets"
        },
        metric_types: %{
          type: :array,
          items: %{type: :string, enum: ["likes", "retweets", "replies", "impressions", "bookmarks", "url_clicks", "profile_clicks"]},
          description: "Types of metrics to collect",
          default: ["likes", "retweets", "replies", "impressions", "bookmarks"]
        },
        granularity: %{
          type: :string,
          description: "Time granularity for metrics aggregation",
          enum: ["day", "week", "month"],
          default: "day"
        },
        start_date: %{
          type: :string,
          description: "Start date in YYYY-MM-DD format"
        },
        end_date: %{
          type: :string,
          description: "End date in YYYY-MM-DD format"
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        metrics: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              tweet_id: %{type: :string},
              likes: %{type: :integer},
              retweets: %{type: :integer},
              replies: %{type: :integer},
              impressions: %{type: :integer},
              bookmarks: %{type: :integer},
              engagement_rate: %{type: :number},
              url_clicks: %{type: :integer},
              profile_clicks: %{type: :integer}
            }
          }
        },
        total_engagement: %{type: :integer},
        average_engagement_rate: %{type: :number},
        top_performing_tweets: %{type: :array},
        daily_breakdown: %{type: :array}
      }
    }

  @doc """
  Fetches engagement metrics for specified tweets or user.
  """
  def focus(params) do
    tweet_ids = Map.get(params, :tweet_ids, params["tweet_ids"] || [])
    user_id = Map.get(params, :user_id, params["user_id"])
    metric_types = Map.get(params, :metric_types, params["metric_types"] || ["likes", "retweets", "replies", "impressions", "bookmarks"])
    granularity = Map.get(params, :granularity, params["granularity"] || "day")
    start_date = Map.get(params, :start_date, params["start_date"])
    end_date = Map.get(params, :end_date, params["end_date"])

    # Fetch tweet data
    tweets = fetch_tweets(tweet_ids, user_id)

    # Calculate metrics
    metrics = Enum.map(tweets, &calculate_metrics(&1, metric_types))

    # Calculate aggregates
    total_engagement = calculate_total_engagement(metrics)
    average_engagement_rate = calculate_average_engagement_rate(metrics)
    top_performing = get_top_performing(metrics, 5)
    daily_breakdown = generate_daily_breakdown(tweets, granularity)

    data = %{
      metrics: metrics,
      total_engagement: total_engagement,
      average_engagement_rate: average_engagement_rate,
      top_performing_tweets: top_performing,
      daily_breakdown: daily_breakdown
    }

    {:ok, data}
  end

  defp fetch_tweets([], nil), do: []
  defp fetch_tweets(tweet_ids, nil) when length(tweet_ids) > 0 do
    ids = Enum.join(tweet_ids, ",")
    query_params = %{
      "ids" => ids,
      "tweet.fields" => "public_metrics,created_at,text"
    }

    case Req.get(@url, params: query_params, headers: get_headers()) do
      {:ok, %{status: 200, body: body}} ->
        Map.get(body, "data", [])

      _ ->
        []
    end
  end

  defp fetch_tweets([], user_id) do
    url = String.replace(@url, "/tweets", "/users/#{user_id}/tweets")
    query_params = %{
      "max_results" => 10,
      "tweet.fields" => "public_metrics,created_at,text"
    }

    case Req.get(url, params: query_params, headers: get_headers()) do
      {:ok, %{status: 200, body: body}} ->
        Map.get(body, "data", [])

      _ ->
        []
    end
  end

  defp get_headers do
    [{"Content-Type", "application/json"}]
  end

  defp calculate_metrics(tweet, metric_types) do
    public_metrics = tweet["public_metrics"] || %{}

    likes = if "likes" in metric_types, do: Map.get(public_metrics, "like_count", 0), else: 0
    retweets = if "retweets" in metric_types, do: Map.get(public_metrics, "retweet_count", 0), else: 0
    replies = if "replies" in metric_types, do: Map.get(public_metrics, "reply_count", 0), else: 0
    impressions = if "impressions" in metric_types, do: Map.get(public_metrics, "impression_count", 0) || 0, else: 0
    bookmarks = if "bookmarks" in metric_types, do: Map.get(public_metrics, "bookmark_count", 0) || 0, else: 0
    url_clicks = if "url_clicks" in metric_types, do: Map.get(public_metrics, "url_clicks", 0) || 0, else: 0
    profile_clicks = if "profile_clicks" in metric_types, do: Map.get(public_metrics, "profile_clicks", 0) || 0, else: 0

    engagement = likes + retweets + replies + bookmarks
    engagement_rate = if impressions > 0, do: Float.round(engagement / impressions * 100, 2), else: 0.0

    %{
      tweet_id: tweet["id"],
      text: tweet["text"],
      created_at: tweet["created_at"],
      likes: likes,
      retweets: retweets,
      replies: replies,
      impressions: impressions,
      bookmarks: bookmarks,
      engagement_rate: engagement_rate,
      url_clicks: url_clicks,
      profile_clicks: profile_clicks
    }
  end

  defp calculate_total_engagement(metrics) do
    Enum.reduce(metrics, 0, fn m, acc ->
      acc + m[:likes] + m[:retweets] + m[:replies] + m[:bookmarks]
    end)
  end

  defp calculate_average_engagement_rate(metrics) do
    case metrics do
      [] -> 0.0
      _ ->
        total_rate = Enum.reduce(metrics, 0.0, fn m, acc -> acc + m[:engagement_rate] end)
        Float.round(total_rate / length(metrics), 2)
    end
  end

  defp get_top_performing(metrics, count) do
    metrics
    |> Enum.sort_by(fn m -> m[:engagement_rate] end, :desc)
    |> Enum.take(count)
  end

  defp generate_daily_breakdown(tweets, granularity) do
    tweets
    |> Enum.group_by(fn tweet ->
      created_at = tweet["created_at"] || ""
      case granularity do
        "day" -> String.slice(created_at, 0, 10)
        "week" -> String.slice(created_at, 0, 7)
        "month" -> String.slice(created_at, 0, 7)
        _ -> String.slice(created_at, 0, 10)
      end
    end)
    |> Enum.map(fn {period, period_tweets} ->
      %{
        period: period,
        tweet_count: length(period_tweets),
        total_engagement: Enum.reduce(period_tweets, 0, fn t, acc ->
          pm = t["public_metrics"] || %{}
          acc + Map.get(pm, "like_count", 0) + Map.get(pm, "retweet_count", 0) + Map.get(pm, "reply_count", 0)
        end)
      }
    end)
    |> Enum.sort_by(fn d -> d.period end, :desc)
  end
end
