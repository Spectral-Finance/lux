defmodule Lux.Lenses.Twitter.GetTweetMetricsLens do
  @moduledoc """
  def fetch_v2(client, tweet_id) do
    with {:ok, response} <- Client.get(client, "/2/statuses/show.json?id=#{tweet_id}") do
      {:ok, parse_metrics(response)}
    rescue
      e in Error -> {:error, e}
    end
  end

  def get_tweet_metrics_v2(client, tweet_id) do
    with {:ok, response} <- Client.get(client, "/2/statuses/show.json?id=#{tweet_id}") do
      {:ok, parse_metrics(response)}
    rescue
      e in Error -> {:error, e}
    end
  end

  defp parse_metrics(%{"retweet_count" => retweet_count, "favorite_count" => favorite_count}) do
    %{
      retweet_count: retweet_count,
      favorite_count: favorite_count
    }
  end
  with {:ok, response} <- Client.get_v2(client, "/2/statuses/show.json?id=#{tweet_id}") do
    {:ok, parse_metrics(response)}
  rescue
    e in Error -> {:error, e}
  end
end

defp parse_metrics(%{"retweet_count" => retweet_count, "favorite_count" => favorite_count}) do
  %{
    retweet_count: retweet_count,
    favorite_count: favorite_count
  }
end