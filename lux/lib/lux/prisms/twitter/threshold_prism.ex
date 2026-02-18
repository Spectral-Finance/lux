defmodule Lux.Prisms.Twitter.ThresholdPrism do
  @moduledoc """
  Prism for handling engagement threshold alerts based on tweet metrics.
  """

  alias Lux.{Client, Error}

  def check_threshold(client, tweet_id, threshold) do
    with {:ok, response} <- Client.get(client, "/1.1/statuses/show.json?id=#{tweet_id}") do
      metrics = parse_metrics(response)
      def check_threshold(client, tweet_id, threshold) do
        with {:ok, response} <- Client.get(client, "/1.1/statuses/show.json?id=#{tweet_id}") do
          metrics = parse_metrics(response)
          if metrics[:retweet_count] > threshold or metrics[:favorite_count] > threshold do
            {:ok, :threshold_exceeded}
          else
            {:ok, :threshold_not_exceeded}
          end
        rescue
          e in Error -> {:error, e}
        end
      end

      def check_engagement_threshold(client, tweet_id, engagement_threshold) do
        with {:ok, response} <- Client.get(client, "/1.1/statuses/show.json?id=#{tweet_id}") do
          metrics = parse_metrics(response)
          total_engagement = metrics[:retweet_count] + metrics[:favorite_count]
          if total_engagement > engagement_threshold do
            send_notification(:engagement_exceeded)
            {:ok, :engagement_exceeded}
          else
            {:ok, :engagement_not_exceeded}
          end
        rescue
          e in Error -> {:error, e}
        end
      end

      defp send_notification(event) do
        # Logic to trigger notifications based on the event
        IO.puts("Notification triggered for #{event}")
      end
    end
  rescue
    e in Error -> {:error, e}
  end
end

def update_thresholds(client, tweet_id, new_threshold) do
  with {:ok, response} <- Client.get(client, "/1.1/statuses/show.json?id=#{tweet_id}") do
    metrics = parse_metrics(response)
    if metrics[:retweet_count] > new_threshold or metrics[:favorite_count] > new_threshold do
      {:ok, :threshold_updated}
    else
      {:ok, :threshold_not_updated}
    end
  rescue
    e in Error -> {:error, e}
  end
end