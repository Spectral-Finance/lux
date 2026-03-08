defmodule Lux.Lenses.Twitter.GetTweet do
  @moduledoc """
  Lens for fetching tweet details via Twitter API v2.

  Retrieves a single tweet by ID with configurable expansions and fields.

  ## Examples

      iex> GetTweet.focus(%{tweet_id: "123456"})
      {:ok, %{id: "123456", text: "Hello!", author_id: "789", ...}}
  """

  alias Lux.Integrations.Twitter.Client

  @default_tweet_fields "id,text,author_id,created_at,public_metrics,conversation_id,in_reply_to_user_id,lang"
  @default_expansions "author_id,attachments.media_keys"

  @doc "Fetches a tweet by ID."
  def focus(params, _opts \\ []) do
    tweet_id = params[:tweet_id] || params["tweet_id"]

    query_params = %{
      "tweet.fields" => params[:tweet_fields] || @default_tweet_fields,
      "expansions" => params[:expansions] || @default_expansions
    }

    query_params =
      if params[:user_fields],
        do: Map.put(query_params, "user.fields", params[:user_fields]),
        else: query_params

    case Client.request(:get, "/tweets/#{tweet_id}", %{params: query_params}) do
      {:ok, %{data: data, includes: includes}} -> {:ok, format_tweet(data, includes)}
      {:ok, %{data: data}} -> {:ok, format_tweet(data, %{})}
      {:error, error} -> {:error, error}
    end
  end

  defp format_tweet(data, includes) do
    tweet_data = data["data"] || data

    author =
      case includes do
        %{"users" => [user | _]} -> %{id: user["id"], name: user["name"], username: user["username"]}
        _ -> nil
      end

    metrics = tweet_data["public_metrics"] || %{}

    %{
      id: tweet_data["id"],
      text: tweet_data["text"],
      author_id: tweet_data["author_id"],
      author: author,
      created_at: tweet_data["created_at"],
      conversation_id: tweet_data["conversation_id"],
      language: tweet_data["lang"],
      metrics: %{
        likes: metrics["like_count"] || 0,
        retweets: metrics["retweet_count"] || 0,
        replies: metrics["reply_count"] || 0,
        quotes: metrics["quote_count"] || 0,
        impressions: metrics["impression_count"] || 0
      }
    }
  end
end
