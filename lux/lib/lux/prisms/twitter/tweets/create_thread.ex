defmodule Lux.Prisms.Twitter.Tweets.CreateThread do
  @moduledoc """
  A prism for creating Twitter threads via the Twitter API v2.

  Posts a sequence of connected tweets as a thread, where each tweet
  replies to the previous one. The first tweet starts the thread and
  subsequent tweets are linked as replies.

  ## Authentication

  Requires OAuth 1.0a User Context authentication. Configure in your application:

      config :lux, :api_keys,
        twitter_consumer_key: "your_consumer_key",
        twitter_consumer_secret: "your_consumer_secret",
        twitter_access_token: "your_access_token",
        twitter_access_token_secret: "your_access_token_secret"

  ## Rate Limits

  100 requests per 24 hours per user. Each tweet in the thread counts as one request.

  ## Examples

      iex> CreateThread.handler(%{
      ...>   tweets: [
      ...>     "1/ Here's a thread about Elixir concurrency...",
      ...>     "2/ First, let's understand processes. In Elixir, every...",
      ...>     "3/ GenServer is the backbone of stateful servers..."
      ...>   ]
      ...> }, %{name: "Agent"})
      {:ok, %{
        thread_id: "1234567890123456789",
        tweet_count: 3,
        tweets: [
          %{id: "1234567890123456789", text: "1/ Here's a thread..."},
          %{id: "1234567890123456790", text: "2/ First, let's understand..."},
          %{id: "1234567890123456791", text: "3/ GenServer is the backbone..."}
        ]
      }}
  """

  alias Lux.Integrations.Twitter

  @twitter_api_url "https://api.twitter.com/2/tweets"

  use Lux.Prism,
    name: "Create Twitter Thread",
    description: "Posts a sequence of connected tweets as a thread via Twitter API v2",
    input_schema: %{
      type: :object,
      properties: %{
        tweets: %{
          type: :array,
          items: %{type: :string},
          description: "List of tweet texts to post in sequence (max 280 chars each)",
          min_items: 2,
          max_items: 25
        },
        reply_settings: %{
          type: :string,
          description: "Who can reply: 'mentionedUsers', 'subscribers', or 'everyone'",
          enum: ["mentionedUsers", "subscribers", "everyone"]
        }
      },
      required: ["tweets"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        thread_id: %{type: :string, description: "ID of the first tweet in the thread"},
        tweet_count: %{type: :integer},
        tweets: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              id: %{type: :string},
              text: %{type: :string}
            }
          }
        }
      }
    }

  @impl true
  def handler(%{"tweets" => tweets} = params, _agent) when is_list(tweets) and length(tweets) >= 2 do
    reply_settings = params["reply_settings"] || "everyone"

    case validate_tweets(tweets) do
      :ok ->
        post_thread(tweets, reply_settings)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def handler(%{"tweets" => [_single]}, _agent) do
    {:error, "Thread must contain at least 2 tweets. Use CreateTweet for single tweets."}
  end

  def handler(_params, _agent) do
    {:error, "Missing required parameter: tweets (must be a list of at least 2 tweet texts)"}
  end

  defp validate_tweets(tweets) do
    invalid = Enum.with_index(tweets) |> Enum.filter(fn {tweet, _} -> String.length(tweet) > 280 end)

    case invalid do
      [] -> :ok
      [{_text, idx} | _] -> {:error, "Tweet at index #{idx} exceeds 280 characters"}
    end
  end

  defp post_thread(tweets, reply_settings) do
    {first_text, remaining} = {hd(tweets), tl(tweets)}

    case post_tweet(first_text, nil, reply_settings) do
      {:ok, first_tweet} ->
        post_thread_replies(remaining, first_tweet, reply_settings, [first_tweet])

      {:error, reason} ->
        {:error, "Failed to post first tweet: #{inspect(reason)}"}
    end
  end

  defp post_thread_replies([], first_tweet, _reply_settings, posted) do
    {:ok, %{
      thread_id: first_tweet.id,
      tweet_count: length(posted),
      tweets: Enum.reverse(posted)
    }}
  end

  defp post_thread_replies([tweet_text | rest], prev_tweet, reply_settings, posted) do
    case post_tweet(tweet_text, prev_tweet.id, reply_settings) do
      {:ok, tweet} ->
        post_thread_replies(rest, tweet, reply_settings, [tweet | posted])

      {:error, reason} ->
        {:error, "Failed to post tweet #{length(posted) + 1} in thread: #{inspect(reason)}"}
    end
  end

  defp post_tweet(text, reply_to_id, reply_settings) do
    body =
      %{"text" => text, "reply_settings" => reply_settings}
      |> maybe_add_reply(reply_to_id)

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", Twitter.build_oauth_header(:post, @twitter_api_url, %{})}
    ]

    [method: :post, url: @twitter_api_url, headers: headers, json: body]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> Req.new()
    |> Req.request()
    |> case do
      {:ok, %{status: 201, body: %{"data" => data}}} ->
        {:ok, %{id: data["id"], text: data["text"]}}

      {:ok, %{status: _status, body: body}} ->
        msg = body["detail"] || body["title"] || "API error"
        {:error, msg}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp maybe_add_reply(body, nil), do: body
  defp maybe_add_reply(body, id), do: Map.put(body, "reply", %{"in_reply_to_tweet_id" => id})
end
