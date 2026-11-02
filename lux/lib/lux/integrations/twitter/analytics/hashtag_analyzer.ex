defmodule Lux.Integrations.Twitter.Analytics.HashtagAnalyzer do
  @moduledoc """
  Analyzes hashtag performance, usage patterns, engagement distribution,
  and trending velocity across Twitter tweets.
  """

  @hashtag_regex ~r/#[a-zA-Z0-9_]+/

  @type hashtag_stat :: %{
          tag: String.t(),
          count: non_neg_integer(),
          total_engagements: non_neg_integer(),
          avg_engagement_per_tweet: float(),
          top_tweet_id: String.t() | nil
        }

  @doc """
  Extracts all hashtags from a tweet text.
  """
  @spec extract_hashtags(String.t()) :: list(String.t())
  def extract_hashtags(text) when is_binary(text) do
    Regex.scan(@hashtag_regex, text)
    |> List.flatten()
    |> Enum.map(&String.downcase/1)
    |> Enum.uniq()
  end

  def extract_hashtags(_), do: []

  @doc """
  Analyzes hashtag distribution and performance metrics across a dataset of tweets.
  """
  @spec analyze_hashtags(list(map())) :: list(hashtag_stat())
  def analyze_hashtags(tweets) when is_list(tweets) do
    tweets
    |> Enum.flat_map(fn tweet ->
      text = Map.get(tweet, :text, Map.get(tweet, "text", ""))
      metrics = Map.get(tweet, :public_metrics, Map.get(tweet, "public_metrics", %{}))
      tweet_id = Map.get(tweet, :id, Map.get(tweet, "id"))

      engagements =
        Map.get(metrics, "like_count", 0) +
        Map.get(metrics, "retweet_count", 0) +
        Map.get(metrics, "reply_count", 0)

      hashtags = extract_hashtags(text)
      Enum.map(hashtags, fn tag -> {tag, tweet_id, engagements} end)
    end)
    |> Enum.group_by(fn {tag, _id, _eng} -> tag end)
    |> Enum.map(fn {tag, occurrences} ->
      count = length(occurrences)
      total_eng = Enum.reduce(occurrences, 0, fn {_t, _id, eng}, acc -> acc + eng end)
      avg_eng = if count > 0, do: Float.round(total_eng / count, 2), else: 0.0

      top_entry = Enum.max_by(occurrences, fn {_t, _id, eng} -> eng end, fn -> nil end)
      top_id = if top_entry, do: elem(top_entry, 1), else: nil

      %{
        tag: tag,
        count: count,
        total_engagements: total_eng,
        avg_engagement_per_tweet: avg_eng,
        top_tweet_id: top_id
      }
    end)
    |> Enum.sort_by(& &1.total_engagements, :desc)
  end
end
