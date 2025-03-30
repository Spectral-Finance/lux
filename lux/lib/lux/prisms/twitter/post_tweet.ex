defmodule Lux.Prisms.Twitter.PostTweet do
  @moduledoc """
  A prism for posting tweets to Twitter.

  This prism provides a simple interface to post tweets using the Twitter API v2. It leverages
  the Twitter API client for making requests and follows a minimalist approach by:

  - Supporting both simple text tweets and tweets with media
  - Passing through Twitter API errors directly for LLM interpretation
  - Providing clear success/failure responses with tweet details

  ## Implementation Details

  - Uses Twitter API v2 endpoint: POST /tweets
  - Returns a response with the tweet ID and content on success
  - Preserves original Twitter API errors for better error handling by LLMs

  ## Examples

      # Post a simple text tweet
      iex> PostTweet.handler(%{
      ...>   text: "Hello, Twitter! This is my first tweet from Lux."
      ...> }, %{name: "Agent"})
      {:ok, %{id: "1234567890", text: "Hello, Twitter! This is my first tweet from Lux."}}

      # Error handling (passed through from Twitter API)
      iex> PostTweet.handler(%{
      ...>   text: "" # Empty tweet will be rejected by Twitter API
      ...> }, %{name: "Agent"})
      {:error, {400, "Tweet text is empty"}}
  """

  use Lux.Prism,
    name: "Post Tweet",
    description: "Posts a new tweet to Twitter",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "The text content of the tweet",
          minLength: 1,
          maxLength: 280
        },
        reply_to: %{
          type: :string,
          description: "Optional tweet ID to reply to",
          pattern: "^[0-9]+$"
        },
        media_ids: %{
          type: :array,
          description: "Optional array of media IDs to attach to the tweet",
          items: %{
            type: :string,
            pattern: "^[0-9]+$"
          }
        }
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{
          type: :string,
          description: "The ID of the created tweet"
        },
        text: %{
          type: :string,
          description: "The text content of the tweet"
        }
      },
      required: ["id", "text"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  @doc """
  Handles the request to post a new tweet.

  This implementation:
  - Makes a direct request to Twitter API using the Client module
  - Returns success/failure responses with relevant tweet information
  - Logs the operation for monitoring purposes
  """
  def handler(params, agent) do
    with {:ok, text} <- validate_param(params, :text) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} posting tweet: #{text}")

      payload = build_tweet_payload(params, text)
      post_tweet(payload)
    end
  end

  defp build_tweet_payload(params, text) do
    # Start with basic text
    payload = %{text: text}

    # Add optional components
    payload
    |> maybe_add_reply_to(params)
    |> maybe_add_media_ids(params)
  end

  defp maybe_add_reply_to(payload, params) do
    case Map.get(params, :reply_to) do
      nil -> payload
      reply_id -> Map.put(payload, :reply, %{in_reply_to_tweet_id: reply_id})
    end
  end

  defp maybe_add_media_ids(payload, params) do
    case Map.get(params, :media_ids) do
      nil -> payload
      [] -> payload
      media_ids -> Map.put(payload, :media, %{media_ids: media_ids})
    end
  end

  defp post_tweet(payload) do
    case Client.request(:post, "/tweets", %{json: payload}) do
      {:ok, %{"data" => tweet_data}} ->
        Logger.info("Successfully posted tweet with ID: #{tweet_data["id"]}")
        {:ok, %{id: tweet_data["id"], text: tweet_data["text"]}}

      error -> handle_tweet_error(error)
    end
  end

  defp handle_tweet_error({:error, {status, %{"detail" => detail}}}) do
    error = {status, detail}
    Logger.error("Failed to post tweet: #{inspect(error)}")
    {:error, error}
  end

  defp handle_tweet_error({:error, {status, body}}) do
    error = {status, body}
    Logger.error("Failed to post tweet: #{inspect(error)}")
    {:error, error}
  end

  defp handle_tweet_error({:error, error}) do
    Logger.error("Failed to post tweet: #{inspect(error)}")
    {:error, error}
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
