defmodule Lux.Prisms.Twitter.Tweets.UnlikeTweet do
  @moduledoc """
  A prism for removing a like from a tweet via the Twitter API v2.

  Removes an existing like from a tweet on behalf of the authenticated user.

  ## Authentication

  Requires OAuth 1.0a User Context authentication. The authenticated user
  must have previously liked the tweet.

  ## Rate Limits

  1,000 unlike operations per 24 hours per user.

  ## Examples

      iex> UnlikeTweet.handler(%{
      ...>   user_id: "123456789",
      ...>   tweet_id: "1234567890123456789"
      ...> }, %{name: "Agent"})
      {:ok, %{liked: false, tweet_id: "1234567890123456789"}}

      iex> UnlikeTweet.handler(%{
      ...>   user_id: "123456789",
      ...>   tweet_id: "0000000000000000000"
      ...> }, %{name: "Agent"})
      {:error, %{title: "Not Found", detail: "Tweet 0000000000000000000 not found"}}
  """

  use Lux.Prism,
    name: "Unlike Tweet",
    description: "Removes a like from a tweet on behalf of the authenticated user via Twitter API v2",
    input_schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :string,
          description: "The authenticated user's ID who is removing the like",
          pattern: "^[0-9]+$"
        },
        tweet_id: %{
          type: :string,
          description: "The unique identifier of the tweet to unlike",
          pattern: "^[0-9]+$"
        }
      },
      required: ["user_id", "tweet_id"]
    }

  alias Lux.Integrations.Twitter

  @twitter_api_base "https://api.twitter.com/2/users"

  @doc """
  Removes a like from a tweet via the Twitter API v2.
  """
  def handler(%{user_id: user_id, tweet_id: tweet_id}, _agent) do
    url = "#{@twitter_api_base}/#{user_id}/likes/#{tweet_id}"

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", Twitter.build_oauth_header(:delete, url, %{})}
    ]

    [method: :delete, url: url, headers: headers]
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
    {:error, %{title: "Forbidden", detail: "Cannot unlike this tweet"}}
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
