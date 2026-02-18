defmodule Lux.Beams.Twitter.AnalyticsBeam do
  @moduledoc """
  Beam for processing Twitter analytics data.
  """

  alias Lux.{Client, Error}

  def process(client, tweet_id) do
    with {:ok, response} <- Client.get(client, "/1.1/statuses/show.json?id=#{tweet_id}") do
      {:ok, parse_metrics(response)}
    rescue
      e in Error -> {:error, e}
    end
  end

  defp parse_metrics(response) do
    %{
      retweet_count: response["retweet_count"],
      favorite_count: response["favorite_count"]
    }
  end
end

def process_tweet_metrics(client, tweet_id) do
  with {:ok, response} <- Client.get(client, "/1.1/statuses/show.json?id=#{tweet_id}") do
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