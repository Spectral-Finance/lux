defmodule Lux.Prisms.Twitter.Tweets.EditTweet do
  @moduledoc """
  A prism for editing tweets via the Twitter API v2.

  Allows editing the text of an existing tweet within the edit window
  (30 minutes from creation, up to 5 edits per tweet).

  ## Authentication

  Requires OAuth 1.0a User Context authentication with write permissions.
  The authenticated user must own the tweet being edited.

  ## Rate Limits

  Limited by the tweet edit feature constraints:
  - Tweets can only be edited within 30 minutes of creation
  - Maximum 5 edits per tweet
  - Not available on all account types

  ## Examples

      iex> EditTweet.handler(%{
      ...>   tweet_id: "1234567890123456789",
      ...>   text: "Updated tweet text!"
      ...> }, %{name: "Agent"})
      {:ok, %{
        id: "1234567890123456789",
        text: "Updated tweet text!",
        edit_history_tweet_ids: ["1234567890123456789"]
      }}

      iex> EditTweet.handler(%{
      ...>   tweet_id: "9999999999999999999",
      ...>   text: "This won't work"
      ...> }, %{name: "Agent"})
      {:error, %{title: "Not Found", detail: "Tweet not found or not owned by this user"}}

      iex> EditTweet.handler(%{
      ...>   tweet_id: "1234567890123456789",
      ...>   text: "Too late to edit"
      ...> }, %{name: "Agent"})
      {:error, %{title: "Forbidden", detail: "Tweet is no longer eligible for editing"}}
  """

  use Lux.Prism,
    name: "Edit Tweet",
    description: "Edits the text of an existing tweet within the 30-minute edit window",
    input_schema: %{
      type: :object,
      properties: %{
        tweet_id: %{
          type: :string,
          description: "The unique identifier of the tweet to edit",
          pattern: "^[0-9]+$"
        },
        text: %{
          type: :string,
          description: "The updated text content of the tweet (max 280 characters)",
          max_length: 280
        }
      },
      required: ["tweet_id", "text"]
    }

  alias Lux.Integrations.Twitter

  @twitter_api_base "https://api.twitter.com/2/tweets"

  @doc """
  Edits a tweet's text via the Twitter API v2.

  Uses OAuth 1.0a authentication with PATCH method.
  """
  def handler(%{tweet_id: tweet_id, text: text}, _agent) do
    url = "#{@twitter_api_base}/#{tweet_id}"
    body = %{"text" => text}

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", Twitter.build_oauth_header(:patch, url, %{})}
    ]

    [method: :patch, url: url, headers: headers, json: body]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.request()
    |> handle_response(tweet_id)
  end

  def handler(%{"tweet_id" => tweet_id, "text" => text}, agent),
    do: handler(%{tweet_id: tweet_id, text: text}, agent)

  defp handle_response({:ok, %{status: status, body: %{"data" => data}}}, _tweet_id)
       when status in 200..299 do
    {:ok,
     %{
       id: data["id"],
       text: data["text"],
       edit_history_tweet_ids: data["edit_history_tweet_ids"] || []
     }}
  end

  defp handle_response({:ok, %{status: 401}}, _tweet_id) do
    {:error, %{title: "Unauthorized", detail: "Invalid or missing OAuth credentials"}}
  end

  defp handle_response({:ok, %{status: 403, body: %{"detail" => detail}}}, _tweet_id) do
    {:error, %{title: "Forbidden", detail: detail}}
  end

  defp handle_response({:ok, %{status: 403}}, _tweet_id) do
    {:error,
     %{title: "Forbidden", detail: "Tweet is not eligible for editing or not owned by this user"}}
  end

  defp handle_response({:ok, %{status: 404}}, tweet_id) do
    {:error,
     %{title: "Not Found", detail: "Tweet #{tweet_id} not found or not owned by this user"}}
  end

  defp handle_response({:ok, %{status: 429}}, _tweet_id) do
    {:error,
     %{title: "Rate Limited", detail: "Twitter API rate limit exceeded. Try again later."}}
  end

  defp handle_response({:ok, %{status: status, body: %{"errors" => [error | _]}}}, _tweet_id) do
    {:error,
     %{
       title: error["title"] || "API Error",
       detail: error["detail"] || error["message"] || "Unknown error",
       status: status
     }}
  end

  defp handle_response({:ok, %{status: status, body: body}}, _tweet_id) do
    {:error, %{title: "Unexpected response", status: status, detail: inspect(body)}}
  end

  defp handle_response({:error, reason}, _tweet_id) do
    {:error, %{title: "Request failed", detail: inspect(reason)}}
  end
end
