defmodule Lux.Prisms.Twitter.Analytics.EngagementReport do
  @moduledoc """
  Prism for generating comprehensive engagement reports from Twitter/X analytics.

  Combines data from multiple Twitter analytics lenses to produce
  actionable engagement reports with growth metrics and sentiment summaries.

  ## Examples

      iex> EngagementReport.handler(%{account_id: "2244994945", period: "7d"}, ctx)
      {:ok, %{report: %{followers: 1000, engagement_rate: 4.5, ...}}}
  """

  use Lux.Prism,
    name: "Twitter Engagement Report Generator",
    description: "Generates comprehensive engagement reports combining follower growth, tweet metrics, and mention analysis",
    input_schema: %{
      type: :object,
      properties: %{
        account_id: %{
          type: :string,
          description: "Twitter user ID to generate report for"
        },
        username: %{
          type: :string,
          description: "Twitter username (without @) as alternative to account_id"
        },
        period: %{
          type: :string,
          description: "Report period: 24h, 7d, 30d",
          enum: ["24h", "7d", "30d"]
        },
        include_mentions: %{
          type: :boolean,
          description: "Include mention/sentiment analysis in report (default: true)"
        },
        include_trends: %{
          type: :boolean,
          description: "Include relevant trending topics in report (default: false)"
        }
      },
      required: ["account_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        report: %{
          type: :object,
          properties: %{
            account: %{type: :string},
            period: %{type: :string},
            follower_metrics: %{type: :object},
            engagement_summary: %{type: :object},
            top_tweets: %{type: :array},
            mention_summary: %{type: :object},
            generated_at: %{type: :string}
          }
        }
      }
    }

  alias Lux.Lenses.Twitter.Analytics.{FollowerGrowth, HashtagPerformance}
  alias Lux.Lenses.Twitter.Monitoring.MentionSentiment

  @impl true
  def handler(input, _ctx) do
    with {:ok, account_id} <- validate_account(input),
         {:ok, period} <- parse_period(input),
         {:ok, follower_data} <- fetch_follower_metrics(account_id, input),
         {:ok, mention_data} <- maybe_fetch_mentions(account_id, input),
         {:ok, report} <- compile_report(account_id, period, follower_data, mention_data) do
      {:ok, %{report: report}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_account(%{account_id: id}) when is_binary(id) and byte_size(id) > 0, do: {:ok, id}
  defp validate_account(%{username: username}) when is_binary(username), do: {:ok, {:username, username}}
  defp validate_account(_), do: {:error, "account_id or username is required"}

  defp parse_period(%{period: period}) when period in ~w(24h 7d 30d), do: {:ok, period}
  defp parse_period(_), do: {:ok, "7d"}

  defp period_to_hours("24h"), do: 24
  defp period_to_hours("7d"), do: 168
  defp period_to_hours("30d"), do: 720

  defp fetch_follower_metrics(account_id, input) do
    params = case account_id do
      {:username, username} -> %{username: username}
      id -> %{user_id: id}
    end

    case FollowerGrowth.focus(params) do
      {:ok, data} -> {:ok, data}
      {:error, _} -> {:ok, %{user_metrics: nil}}
    end
  end

  defp maybe_fetch_mentions(account_id, %{include_mentions: false}), do: {:ok, nil}
  defp maybe_fetch_mentions(account_id, input) do
    query = case account_id do
      {:username, username} -> "@#{username}"
      _ -> "from:#{account_id}"
    end

    hours = period_to_hours(Map.get(input, :period, "7d"))
    start_time = DateTime.utc_now() |> DateTime.add(-hours, :hour) |> DateTime.to_iso8601()

    case MentionSentiment.focus(%{query: query, start_time: start_time, max_results: 100}) do
      {:ok, data} -> {:ok, data}
      {:error, _} -> {:ok, nil}
    end
  end

  defp compile_report(account_id, period, follower_data, mention_data) do
    user_metrics = Map.get(follower_data, :user_metrics, %{})
    mention_list = Map.get(mention_data, :mentions, [])

    total_engagement = calculate_total_engagement(mention_list)
    sentiment_breakdown = analyze_sentiment(mention_list)

    {:ok, %{
      account: format_account(account_id),
      period: period,
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      follower_metrics: %{
        followers: get_in(user_metrics, [:followers]) || 0,
        following: get_in(user_metrics, [:following]) || 0,
        tweets: get_in(user_metrics, [:tweets]) || 0,
        listed: get_in(user_metrics, [:listed]) || 0,
        verified: get_in(user_metrics, [:verified]) || false
      },
      engagement_summary: %{
        total_mentions: length(mention_list),
        total_engagement: total_engagement,
        sentiment: sentiment_breakdown,
        engagement_rate: calculate_engagement_rate(total_engagement, get_in(user_metrics, [:followers]) || 0)
      },
      top_tweets: extract_top_tweets(mention_list, 5)
    }}
  end

  defp format_account({:username, username}), do: "@#{username}"
  defp format_account(id), do: id

  defp calculate_total_engagement(mentions) do
    Enum.reduce(mentions, 0, fn m, acc ->
      engagement = Map.get(m, :engagement, %{})
      acc + Map.get(engagement, :likes, 0) + Map.get(engagement, :retweets, 0) + Map.get(engagement, :replies, 0)
    end)
  end

  defp analyze_sentiment(mentions) do
    # Basic sentiment classification based on engagement patterns
    total = length(mentions)
    if total == 0 do
      %{positive: 0, neutral: 0, negative: 0, total: 0}
    else
      # Simple heuristic: high engagement = positive signal, low = neutral, sensitive flag = negative
      {pos, neu, neg} = Enum.reduce(mentions, {0, 0, 0}, fn m, {p, n, neg} ->
        eng = Map.get(m, :engagement, %{})
        likes = Map.get(eng, :likes, 0)
        sensitive = Map.get(m, :possibly_sensitive, false)

        cond do
          sensitive -> {p, n, neg + 1}
          likes > 10 -> {p + 1, n, neg}
          true -> {p, n + 1, neg}
        end
      end)

      %{positive: pos, neutral: neu, negative: neg, total: total}
    end
  end

  defp calculate_engagement_rate(total_engagement, followers) when followers > 0 do
    Float.round(total_engagement / followers * 100, 2)
  end
  defp calculate_engagement_rate(_, _), do: 0.0

  defp extract_top_tweets(mentions, limit) do
    mentions
    |> Enum.sort_by(fn m ->
      eng = Map.get(m, :engagement, %{})
      Map.get(eng, :likes, 0) + Map.get(eng, :retweets, 0)
    end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn m ->
      %{
        tweet_id: m.tweet_id,
        text: m.text,
        engagement: m.engagement,
        created_at: m.created_at
      }
    end)
  end
end
