defmodule Lux.Integrations.Twitter.Automation.ContentCurator do
  @moduledoc """
  Automates Twitter content discovery, quality scoring, deduplication,
  and generates curation proposals (Quote Tweets, Retweets, Roundups).
  """

  @type curated_item :: %{
          tweet_id: String.t(),
          author: map(),
          text: String.t(),
          metrics: map(),
          score: float(),
          recommended_action: :quote_tweet | :retweet | :bookmark,
          suggested_commentary: String.t()
        }

  @doc """
  Scores and ranks a list of candidate tweets for curation.
  Filters out already curated tweet IDs and evaluates engagement velocity.
  """
  @spec rank_content(list(map()), list(String.t()), map()) :: list(curated_item())
  def rank_content(candidates, seen_ids \\ [], opts \\ %{}) when is_list(candidates) do
    min_score = Map.get(opts, :min_score, 10.0)

    candidates
    |> Enum.reject(fn tweet ->
      id = Map.get(tweet, :id) || Map.get(tweet, "id")
      id in seen_ids
    end)
    |> Enum.map(&score_tweet/1)
    |> Enum.filter(&(&1.score >= min_score))
    |> Enum.sort_by(& &1.score, :desc)
  end

  @doc """
  Computes a weighted quality score for a tweet based on engagement, media, and author authority.
  """
  @spec score_tweet(map()) :: curated_item()
  def score_tweet(tweet) do
    metrics = Map.get(tweet, :public_metrics) || Map.get(tweet, "public_metrics") || %{}
    retweets = Map.get(metrics, :retweet_count) || Map.get(metrics, "retweet_count", 0)
    likes = Map.get(metrics, :like_count) || Map.get(metrics, "like_count", 0)
    quotes = Map.get(metrics, :quote_count) || Map.get(metrics, "quote_count", 0)
    replies = Map.get(metrics, :reply_count) || Map.get(metrics, "reply_count", 0)

    author = Map.get(tweet, :author) || Map.get(tweet, "author") || %{}
    is_verified = Map.get(author, :verified, false) || Map.get(author, "verified", false)
    followers = get_in(author, [:public_metrics, :followers_count]) || get_in(author, ["public_metrics", "followers_count"]) || 1000

    has_media = not Enum.empty?(Map.get(tweet, :attachments) || Map.get(tweet, "attachments", %{}) |> Map.get(:media_keys, []))

    # Weight formula:
    # Likes * 1 + Retweets * 3 + Quotes * 4 + Replies * 2 + Media Bonus (25) + Verified Bonus (50)
    base_score =
      likes * 1.0 +
      retweets * 3.0 +
      quotes * 4.0 +
      replies * 2.0 +
      (if has_media, do: 25.0, else: 0.0) +
      (if is_verified, do: 50.0, else: 0.0)

    log_follower_factor = max(1.0, :math.log10(max(10, followers)))
    normalized_score = Float.round(base_score / log_follower_factor, 2)

    action =
      cond do
        normalized_score >= 100.0 -> :quote_tweet
        normalized_score >= 40.0 -> :retweet
        true -> :bookmark
      end

    suggested_comment = generate_curation_commentary(action, tweet)

    %{
      tweet_id: to_string(Map.get(tweet, :id) || Map.get(tweet, "id")),
      author: author,
      text: Map.get(tweet, :text) || Map.get(tweet, "text") || "",
      metrics: %{likes: likes, retweets: retweets, quotes: quotes, replies: replies},
      score: normalized_score,
      recommended_action: action,
      suggested_commentary: suggested_comment
    }
  end

  defp generate_curation_commentary(:quote_tweet, tweet) do
    author_username = get_in(tweet, [:author, :username]) || get_in(tweet, ["author", "username"]) || "author"
    "Great insights by @#{author_username} on this development. What are your thoughts on this approach?"
  end

  defp generate_curation_commentary(_, _), do: ""
end
