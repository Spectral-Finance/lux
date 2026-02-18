defmodule Lux.Prisms.Twitter.AnalyzeEngagementPrism do
  @moduledoc """
  Prism for analyzing engagement metrics from Twitter.
  """

  alias Lux.{Client, Error}

  def analyze(client, tweet_id) do
    with {:ok, response} <- Client.get(client, "/1.1/statuses/show.json?id=#{tweet_id}") do
      {:ok, parse_engagement(response)}
    rescue
      e in Error -> {:error, e}
    end
  end

  defp parse_engagement(response) do
    %{
      retweet_count: response["retweet_count"],
      favorite_count: response["favorite_count"]
    }
  end
end

def analyze_engagement(client, tweet_id) do
  with {:ok, response} <- Client.get(client, "/1.1/statuses/show.json?id=#{tweet_id}") do
    {:ok, parse_engagement(response)}
  rescue
    e in Error -> {:error, e}
  end
end

defp parse_engagement(response) do
  %{
    retweet_count: response["retweet_count"],
    favorite_count: response["favorite_count"]
  }
end