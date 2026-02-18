defmodule Lux.Prisms.Twitter.HashtagPerformanceAnalyzerPrism do
  @moduledoc """
  Prism for analyzing hashtag performance on Twitter.
  """

  alias Lux.{Client, Error}

  def analyze(client, hashtag) do
    with {:ok, response} <- Client.get(client, "/1.1/search/tweets.json?q=##{hashtag}") do
      {:ok, parse_performance(response)}
    rescue
      e in Error -> {:error, e}
    end
  end

  defp parse_performance(response) do
    tweets = response["statuses"]
    %{
      tweet_count: length(tweets),
      retweet_count: Enum.sum(Enum.map(tweets, fn tweet -> tweet["retweet_count"] end)),
      favorite_count: Enum.sum(Enum.map(tweets, fn tweet -> tweet["favorite_count"] end))
    }
  end
end

def analyze_hashtag_performance(client, hashtag) do
  with {:ok, response} <- Client.get(client, "/1.1/search/tweets.json?q=##{hashtag}") do
    {:ok, parse_performance(response)}
  rescue
    e in Error -> {:error, e}
  end
end

defp parse_performance(response) do
  tweets = response["statuses"]
  %{
    tweet_count: length(tweets),
    retweet_count: Enum.sum(Enum.map(tweets, fn tweet -> tweet["retweet_count"] end)),
    favorite_count: Enum.sum(Enum.map(tweets, fn tweet -> tweet["favorite_count"] end))
  }
end