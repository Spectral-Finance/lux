defmodule Lux.Prisms.Twitter.Tweets.DeleteTweet do
  @moduledoc """
  A prism for deleting tweets via the Twitter API v2.

  Deletes a tweet owned by the authenticated user. You can only delete
  tweets you own. Deleted tweets cannot be recovered.

  ## Authentication

  Requires OAuth 1.0a User Context authentication with the same account
  that owns the tweet being deleted.

  ## Rate Limits

  50 requests per 15 minutes per user.

  ## Examples

      iex> DeleteTweet.handler(%{
      ...>   tweet_id: "1234567890123456789"
      ...> }, %{name: "Agent"})
      {:ok, %{deleted: true, tweet_id: "1234567890123456789"}}

      iex> DeleteTweet.handler(%{
      ...>   tweet_id: "9999999999999999999"  # non-existent or not owned
      ...> }, %{name: "Agent"})
      {:error, %{title: "Not Found", detail: "Tweet not found or not owned by this user"}}
  """

  use Lux.Prism,
    name: "Delete Tweet",
    description: "Deletes a tweet owned by the authenticated user via Twitter API v2",
    input_schema: %{
      type: :object,
      properties: %{
        tweet_id: %{
          type: :string,
          description: "The unique identifier of the tweet to delete",
          pattern: "^[0-9]+$"
        }
      },
      required: ["tweet_id"]
    }

  alias Lux.Integrations.Twitter

  @twitter_api_base "https://api.twitter.com/2/tweets"

  @doc """
  Deletes a tweet by ID via the Twitter API v2.
  """
  def handler(%{tweet_id: tweet_id}, _agent) do
    url = "#{@twitter_api_base}/#{tweet_id}"

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

  defp handle_response({:ok, %{status: status, body: %{"data" => %{"deleted" => true}}}}, _tweet_id)
       when status in 200..299 do
    {:ok, %{deleted: true}}
  end

  defp handle_response({:ok, %{status: 401}}, _tweet_id) do
    {:error, %{title: "Unauthorized", detail: "Invalid or missing OAuth credentials"}}
  end

  defp handle_response({:ok, %{status: 403, body: %{"detail" => detail}}}, _tweet_id) do
    {:error, %{title: "Forbidden", detail: detail}}
  end

  defp handle_response({:ok, %{status: 404}}, tweet_id) do
    {:error, %{title: "Not Found", detail: "Tweet #{tweet_id} not found or not owned by this user"}}
  end

  defp handle_response({:ok, %{status: 429}}, _tweet_id) do
    {:error, %{title: "Rate Limited", detail: "Twitter API rate limit exceeded. Try again later."}}
  end

  defp handle_response({:ok, %{status: status, body: body}}, _tweet_id) do
    {:error, %{title: "Unexpected response", status: status, detail: inspect(body)}}
  end

  defp handle_response({:error, reason}, _tweet_id) do
    {:error, %{title: "Request failed", detail: inspect(reason)}}
  end

end
