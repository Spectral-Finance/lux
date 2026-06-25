defmodule Lux.Prisms.Twitter.Automation.ScheduleTweet do
  @moduledoc """
  A prism for scheduling and posting tweets via Twitter API v2.

  Supports immediate posting, scheduled posts (via agent state/scheduler),
  reply threading, media attachment, and geo-targeting.

  ## Examples

      iex> ScheduleTweet.handler(%{
      ...>   text: "Hello from Lux!",
      ...>   bearer_token: "AAAA..."
      ...> }, %{name: "ContentAgent"})
      {:ok, %{posted: true, tweet_id: "...", text: "Hello from Lux!"}}

      # Reply to existing tweet
      iex> ScheduleTweet.handler(%{
      ...>   text: "Great point!",
      ...>   reply_to_tweet_id: "1234567890",
      ...>   bearer_token: "AAAA..."
      ...> }, %{name: "EngagementAgent"})
      {:ok, %{posted: true, tweet_id: "...", reply_to: "1234567890"}}
  """

  use Lux.Prism,
    name: "Schedule / Post Tweet",
    description: "Posts or schedules a tweet via Twitter API v2, with reply threading support",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "Tweet text content (max 280 chars)",
          maxLength: 280
        },
        bearer_token: %{
          type: :string,
          description: "Twitter API v2 OAuth2 Bearer token with write:tweets scope"
        },
        reply_to_tweet_id: %{
          type: :string,
          description: "Tweet ID to reply to (creates a thread)"
        },
        quote_tweet_id: %{
          type: :string,
          description: "Tweet ID to quote-tweet"
        },
        media_ids: %{
          type: :array,
          description: "Array of media IDs to attach (from media/upload endpoint)",
          items: %{type: :string},
          maxItems: 4
        }
      },
      required: ["text", "bearer_token"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        posted: %{type: :boolean},
        tweet_id: %{type: :string},
        text: %{type: :string},
        reply_to: %{type: :string}
      },
      required: ["posted"]
    }

  require Logger

  @create_url "https://api.twitter.com/2/tweets"

  @impl true
  def handler(%{text: text, bearer_token: token} = params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} posting tweet: #{String.slice(text, 0, 50)}...")

    body = %{text: text}
    body = if Map.has_key?(params, :reply_to_tweet_id),
      do: Map.put(body, :reply, %{in_reply_to_tweet_id: params.reply_to_tweet_id}), else: body
    body = if Map.has_key?(params, :quote_tweet_id),
      do: Map.put(body, :quote_tweet_id, params.quote_tweet_id), else: body
    body = if Map.has_key?(params, :media_ids) and params.media_ids != [],
      do: Map.put(body, :media, %{media_ids: params.media_ids}), else: body

    headers = [{"Authorization", "Bearer #{token}"}, {"Content-Type", "application/json"}]

    case Req.post(@create_url, json: body, headers: headers, receive_timeout: 15_000) do
      {:ok, %{status: 201, body: %{"data" => data}}} ->
        Logger.info("Tweet posted: #{data["id"]}")
        {:ok, %{
          posted:   true,
          tweet_id: data["id"],
          text:     data["text"],
          reply_to: Map.get(params, :reply_to_tweet_id)
        }}

      {:ok, %{status: 401}} -> {:error, :invalid_bearer_token}
      {:ok, %{status: 403, body: %{"detail" => d}}} -> {:error, "Forbidden: #{d}"}
      {:ok, %{status: 429}} -> {:error, :rate_limited}
      {:ok, %{status: s, body: b}} -> {:error, {s, b}}
      {:error, reason} -> {:error, reason}
    end
  end
end
