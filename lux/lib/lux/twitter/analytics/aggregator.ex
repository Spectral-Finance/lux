defmodule Lux.Twitter.Analytics.Aggregator do
  @moduledoc """
  Data aggregation, hashtag performance analysis, and custom metric definitions
  for Twitter analytics in Lux.
  """

  @doc """
  Analyzes hashtag occurrences, reach, and performance across tweets.
  """
  @spec analyze_hashtags(list(map())) :: map()
  def analyze_hashtags(tweets) do
    # Each tweet is %{hashtags: ["ai", "crypto"], impressions: 1000, engagements: 50}
    Enum.reduce(
      tweets,
      %{},
      fn tweet, acc ->
        tags = Map.get(tweet, :hashtags, []) || Map.get(tweet, "hashtags", [])
        impressions = Map.get(tweet, :impressions, 0) || Map.get(tweet, "impressions", 0)
        engagements = Map.get(tweet, :engagements, 0) || Map.get(tweet, "engagements", 0)

        Enum.reduce(tags, acc, fn tag, inner_acc ->
          clean_tag = String.downcase(tag) |> String.replace("#", "")

          existing =
            Map.get(inner_acc, clean_tag, %{
              count: 0,
              total_impressions: 0,
              total_engagements: 0
            })

          updated = %{
            count: existing.count + 1,
            total_impressions: existing.total_impressions + impressions,
            total_engagements: existing.total_engagements + engagements
          }

          Map.put(inner_acc, clean_tag, updated)
        end)
      end
    )
  end

  @doc """
  Calculates custom engagement metrics:
  - `viral_coefficient`: retweets / original views ratio
  - `interaction_index`: composite weighted score of likes, retweets, and comments
  """
  @spec calculate_custom_metrics(map()) :: map()
  def calculate_custom_metrics(metrics) do
    retweets = Map.get(metrics, :retweets, 0) || Map.get(metrics, "retweets", 0)
    impressions = Map.get(metrics, :impressions, 1) || Map.get(metrics, "impressions", 1)
    likes = Map.get(metrics, :likes, 0) || Map.get(metrics, "likes", 0)
    replies = Map.get(metrics, :replies, 0) || Map.get(metrics, "replies", 0)

    viral_coeff = Float.round((retweets * 1000) / max(impressions, 1), 3)
    interaction_idx = Float.round(likes * 1.0 + retweets * 2.5 + replies * 3.0, 1)

    %{
      viral_coefficient: viral_coeff,
      interaction_index: interaction_idx,
      amplification_rate: if(retweets > 0, do: Float.round(retweets / (likes + 1), 2), else: 0.0)
    }
  end
end
