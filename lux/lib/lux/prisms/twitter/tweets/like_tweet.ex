defmodule Lux.Prisms.Twitter.Tweets.LikeTweet do
  @moduledoc """
  A prism for liking tweets via the Twitter API v2.

  Adds a like on behalf of the authenticated user to a specified tweet.

  ## Authentication

  Requires OAuth 1.0a User Context authentication. The authenticated user
  will be the one liking the tweet.

  ## Rate Limits

  1,000 likes per 24 hours per user.

  ## Examples

      iex> LikeTweet.handler(%{
      ...>   user_id: "123456789",
      ...>   tweet_id: "1234567890123456789"
      ...> }, %{name: "Agent"})
      {:ok, %{liked: true, tweet_id: "1234567890123456789"}}

      iex> LikeTweet.handler(%{
      ...>   user_id: "123456789",
      ...>   tweet_id: "0000000000000000000"
      ...> }, %{name: "Agent"})
      {:error, %{title: "Not Found", detail: "Tweet 0000000000000000000 not found"}}
  """

  use Lux.Prism,
    name: "Like Tweet",
    description: "Likes a tweet on behalf of the authenticated user via Twitter API v2",
    input_schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :string,
          description: "The authenticated user's ID who is liking the tweet",
          pattern: "^[0-9]+$"
        },
        tweet_id: %{
          type: :string,
          description: "The unique identifier of the tweet to like",
          pattern: "^[0-9]+$"
        }
      },
      required: ["user_id", "tweet_id"]
    }

  alias Lux.Integrations.Twitter

  @twitter_api_base "https://api.twitter.com/2/users"

  @doc """
  Likes a tweet via the Twitter API v2.
  """
  def handler(%{user_id: user_id, tweet_id: tweet_id}, _agent) do
    url = "#{@twitter_api_base}/#{user_id}/likes"
    body = %{"tweet_id" => tweet_id}

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", Twitter.build_oauth_header(:post, url, %{})}
    ]

    [method: :post, url: url, headers: headers, json: body]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.request()
    |> handle_response(tweet_id)
  end

  def handler(%{"user_id" => user_id, "tweet_id" => tweet_id}, agent),
    do: handler(%{user_id: user_id, tweet_id: tweet_id}, agent)

  defp handle_response({:ok, %{status: status, body: %{"data" => %{"liked" => liked}}}}, tweet_id)
       when status in 200..299 do
    {:ok, %{liked: liked, tweet_id: tweet_id}}
  end

  defp handle_response({:ok, %{status: 401}}, _tweet_id) do
    {:error, %{title: "Unauthorized", detail: "Invalid or missing OAuth credentials"}}
  end

  defp handle_response({:ok, %{status: 403, body: %{"detail" => detail}}}, _tweet_id) do
    {:error, %{title: "Forbidden", detail: detail}}
  end

  defp handle_response({:ok, %{status: 403}}, _tweet_id) do
    {:error, %{title: "Forbidden", detail: "Cannot like this tweet"}}
  end

  defp handle_response({:ok, %{status: 404}}, tweet_id) do
    {:error, %{title: "Not Found", detail: "Tweet #{tweet_id} not found"}}
  end

  defp handle_response({:ok, %{status: 429}}, _tweet_id) do
    {:error,
     %{title: "Rate Limited", detail: "Twitter API rate limit exceeded. Try again later."}}
  end

  defp handle_response({:ok, %{status: status, body: body}}, _tweet_id) do
    {:error, %{title: "Unexpected response", status: status, detail: inspect(body)}}
  end

  defp handle_response({:error, reason}, _tweet_id) do
    {:error, %{title: "Request failed", detail: inspect(reason)}}
  end
end
