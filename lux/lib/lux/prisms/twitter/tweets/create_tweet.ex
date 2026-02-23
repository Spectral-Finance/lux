defmodule Lux.Prisms.Twitter.Tweets.CreateTweet do
  @moduledoc """
  A prism for creating tweets via the Twitter API v2.

  This prism allows posting new tweets, threads, replies, and quote tweets.
  Supports attaching media and setting reply settings.

  ## Authentication

  Requires OAuth 1.0a User Context authentication. Configure in your application:

      config :lux, :api_keys,
        twitter_consumer_key: "your_consumer_key",
        twitter_consumer_secret: "your_consumer_secret",
        twitter_access_token: "your_access_token",
        twitter_access_token_secret: "your_access_token_secret"

  ## Rate Limits

  100 requests per 24 hours per user (user-level). 200 posts per 24 hours (app-level).

  ## Examples

      iex> CreateTweet.handler(%{
      ...>   text: "Hello, world! This is my first tweet via Lux."
      ...> }, %{name: "Agent"})
      {:ok, %{id: "1234567890123456789", text: "Hello, world! This is my first tweet via Lux."}}

      iex> CreateTweet.handler(%{
      ...>   text: "Replying to your question!",
      ...>   reply: %{in_reply_to_tweet_id: "9876543210987654321"}
      ...> }, %{name: "Agent"})
      {:ok, %{id: "...", text: "Replying to your question!"}}

      iex> CreateTweet.handler(%{
      ...>   text: "Great article!",
      ...>   quote_tweet_id: "1111111111111111111"
      ...> }, %{name: "Agent"})
      {:ok, %{id: "...", text: "Great article!"}}
  """

  use Lux.Prism,
    name: "Create Tweet",
    description: "Posts a new tweet via the Twitter API v2",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "The text content of the tweet (max 280 characters)",
          max_length: 280
        },
        reply: %{
          type: :object,
          description: "Reply configuration if this tweet is a reply",
          properties: %{
            in_reply_to_tweet_id: %{
              type: :string,
              description: "The ID of the tweet being replied to"
            },
            exclude_reply_user_ids: %{
              type: :array,
              items: %{type: :string},
              description: "List of user IDs to exclude from the reply @mention"
            }
          },
          required: ["in_reply_to_tweet_id"]
        },
        quote_tweet_id: %{
          type: :string,
          description: "The ID of the tweet to quote"
        },
        media: %{
          type: :object,
          description: "Media to attach to the tweet",
          properties: %{
            media_ids: %{
              type: :array,
              items: %{type: :string},
              description: "List of media IDs to attach (max 4 images or 1 video/GIF)"
            },
            tagged_user_ids: %{
              type: :array,
              items: %{type: :string},
              description: "List of user IDs to tag in the media"
            }
          },
          required: ["media_ids"]
        },
        reply_settings: %{
          type: :string,
          description:
            "Who can reply to this tweet: mentionedUsers, subscribers, or everyone (default)",
          enum: ["everyone", "mentionedUsers", "subscribers"]
        },
        for_super_followers_only: %{
          type: :boolean,
          description: "Post this tweet exclusively for Super Followers"
        }
      }
    }

  alias Lux.Integrations.Twitter

  @twitter_api_url "https://api.twitter.com/2/tweets"

  @doc """
  Creates a new tweet via the Twitter API v2.

  Builds the request body from parameters and posts to the Twitter API
  using OAuth 1.0a authentication.
  """
  def handler(params, _agent) do
    body = build_request_body(params)
    token = Application.get_env(:lux, :api_keys, [])

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization",
       Twitter.build_oauth_header(:post, @twitter_api_url, %{})}
    ]

    request = [
      method: :post,
      url: @twitter_api_url,
      headers: headers,
      json: body
    ]

    request
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.request()
    |> handle_response()
  end

  defp build_request_body(params) do
    %{}
    |> maybe_put("text", params[:text])
    |> maybe_put("reply", params[:reply] && transform_reply(params[:reply]))
    |> maybe_put("quote_tweet_id", params[:quote_tweet_id])
    |> maybe_put("media", params[:media] && transform_media(params[:media]))
    |> maybe_put("reply_settings", params[:reply_settings])
    |> maybe_put("for_super_followers_only", params[:for_super_followers_only])
  end

  defp transform_reply(%{in_reply_to_tweet_id: id} = reply) do
    base = %{"in_reply_to_tweet_id" => id}

    if reply[:exclude_reply_user_ids] do
      Map.put(base, "exclude_reply_user_ids", reply[:exclude_reply_user_ids])
    else
      base
    end
  end

  defp transform_reply(%{"in_reply_to_tweet_id" => _} = reply), do: reply

  defp transform_media(%{media_ids: ids} = media) do
    base = %{"media_ids" => ids}

    if media[:tagged_user_ids] do
      Map.put(base, "tagged_user_ids", media[:tagged_user_ids])
    else
      base
    end
  end

  defp transform_media(%{"media_ids" => _} = media), do: media

  defp handle_response({:ok, %{status: status, body: %{"data" => data}}})
       when status in 200..299 do
    {:ok, %{
      id: data["id"],
      text: data["text"]
    }}
  end

  defp handle_response({:ok, %{status: 401}}) do
    {:error, %{title: "Unauthorized", detail: "Invalid or missing OAuth credentials"}}
  end

  defp handle_response({:ok, %{status: 403, body: %{"detail" => detail}}}) do
    {:error, %{title: "Forbidden", detail: detail}}
  end

  defp handle_response({:ok, %{status: 429}}) do
    {:error, %{title: "Rate Limited", detail: "Twitter API rate limit exceeded. Try again later."}}
  end

  defp handle_response({:ok, %{status: status, body: %{"errors" => [error | _]}}}) do
    {:error, %{
      title: error["title"] || "API Error",
      detail: error["detail"] || error["message"] || "Unknown error",
      status: status
    }}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    {:error, %{title: "Unexpected response", status: status, detail: inspect(body)}}
  end

  defp handle_response({:error, reason}) do
    {:error, %{title: "Request failed", detail: inspect(reason)}}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
