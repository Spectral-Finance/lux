defmodule Lux.Prisms.Twitter.SentimentScoringPrism do
  @moduledoc """
  Prism for scoring tweet sentiment.
  """

  alias Lux.{Client, Error}

  def score(client, tweet_id) do
    with {:ok, response} <- Client.get(client, "/1.1/statuses/show.json?id=#{tweet_id}") do
      {:ok, calculate_sentiment(response)}
    rescue
      e in Error -> {:error, e}
    end
  end

  defp calculate_sentiment(response) do
    retweet_count = response["retweet_count"]
    favorite_count = response["favorite_count"]

    sentiment_score = (retweet_count - favorite_count) / (retweet_count + favorite_count)

    sentiment_score
  end
end

def score_mentions(client, mentions) do
  Enum.map(mentions, fn mention ->
    with {:ok, response} <- Client.get(client, "/1.1/statuses/show.json?id=#{mention}") do
      calculate_sentiment(response)
    rescue
      e in Error -> {:error, e}
    end
  end)
end

defp calculate_sentiment(response) do
  retweet_count = response["retweet_count"]
  favorite_count = response["favorite_count"]

  sentiment_score = (retweet_count - favorite_count) / (retweet_count + favorite_count)

  sentiment_score
end