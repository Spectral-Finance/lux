defmodule TwitterSearch.Lens do
  @moduledoc """
  A lens for searching Twitter by keyword using the Twitter API v2.
  """
  use Lux.Lens
  
  require Logger

  @doc """
  Searches Twitter for tweets matching the given keyword.
  Returns a list of tweets with relevant metadata.
  """
  def search(keyword) when is_binary(keyword) do
    with {:ok, client} <- get_twitter_client(),
         {:ok, tweets} <- fetch_tweets(client, keyword) do
      {:ok, format_tweets(tweets)}
    else
      {:error, reason} ->
        Logger.error("Failed to search tweets: #{inspect(reason)}")
        {:error, "Failed to fetch tweets"}
    end
  end

  defp get_twitter_client do
    case Application.get_env(:twitter_search, :twitter_credentials) do
      nil ->
        {:error, "Twitter credentials not configured"}
      credentials ->
        {:ok, ExTwitter.configure(credentials)}
    end
  end

  defp fetch_tweets(client, keyword) do
    try do
      tweets = ExTwitter.search(keyword, count: 10)
      {:ok, tweets}
    rescue
      e in ExTwitter.Error ->
        Logger.error("Twitter API error: #{inspect(e)}")
        {:error, "Twitter API error"}
    end
  end

  defp format_tweets(tweets) do
    Enum.map(tweets, fn tweet ->
      %{
        id: tweet.id,
        text: tweet.text,
        user: %{
          name: tweet.user.name,
          screen_name: tweet.user.screen_name,
          profile_image: tweet.user.profile_image_url_https
        },
        created_at: tweet.created_at,
        retweet_count: tweet.retweet_count,
        favorite_count: tweet.favorite_count
      }
    end)
  end
end
