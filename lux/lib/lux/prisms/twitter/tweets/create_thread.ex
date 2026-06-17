defmodule Lux.Prisms.Twitter.Tweets.CreateThread do
  @moduledoc """
  A prism for creating a thread of tweets via Twitter API v2.

  Posts multiple tweets as a reply chain, forming a thread.

  ## Examples

      iex> CreateThread.handler(%{
      ...>   tweets: [
      ...>     "Thread start: Let me explain something...",
      ...>     "First, consider this point...",
      ...>     "And finally, the conclusion."
      ...>   ]
      ...> }, %{name: "Agent"})
      {:ok, %{
        created: true,
        tweet_ids: ["111", "222", "333"],
        count: 3
      }}
  """

  use Lux.Prism,
    name: "Create Thread",
    description: "Creates a thread of tweets on Twitter",
    input_schema: %{
      type: :object,
      properties: %{
        tweets: %{
          type: :array,
          description: "List of tweet texts to post as a thread (2-25 tweets)",
          items: %{type: :string, minLength: 1, maxLength: 280},
          minItems: 1,
          maxItems: 25
        },
        media_ids: %{
          type: :array,
          description: "Media IDs for the first tweet (subsequent tweets won't have media)",
          items: %{type: :string}
        }
      },
      required: ["tweets"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{
          type: :boolean,
          description: "Whether the thread was successfully created"
        },
        tweet_ids: %{
          type: :array,
          description: "List of tweet IDs in the thread",
          items: %{type: :string}
        },
        count: %{
          type: :integer,
          description: "Number of tweets in the thread"
        }
      },
      required: ["created"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  @doc """
  Handles the request to create a thread of tweets.
  """
  def handler(params, agent) do
    tweets = params[:tweets] || params["tweets"]

    with {:ok, tweets} <- validate_tweets(tweets) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} creating thread with #{length(tweets)} tweets")

      media_ids = params[:media_ids] || params["media_ids"]
      result = post_thread(tweets, media_ids, [])

      case result do
        {:ok, tweet_ids} ->
          Logger.info("Successfully created thread with #{length(tweet_ids)} tweets")
          {:ok, %{created: true, tweet_ids: tweet_ids, count: length(tweet_ids)}}

        {:error, reason} ->
          Logger.error("Failed to create thread: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp post_thread([], _media_ids, acc), do: {:ok, Enum.reverse(acc)}

  defp post_thread([text | rest], media_ids, acc) do
    json = %{"text" => text}

    json =
      case {acc, media_ids} do
        {[], ids} when is_list(ids) and length(ids) > 0 ->
          Map.put(json, "media", %{"media_ids" => ids})

        {[last_id | _], _} ->
          Map.put(json, "reply", %{"in_reply_to_tweet_id" => last_id})

        _ ->
          if length(acc) > 0 do
            Map.put(json, "reply", %{"in_reply_to_tweet_id" => hd(acc)})
          else
            json
          end
      end

    case Client.request(:post, "/tweets", %{json: json}) do
      {:ok, %{"data" => %{"id" => tweet_id}}} ->
        # Small delay to avoid rate limiting between thread tweets
        if length(rest) > 0, do: Process.sleep(1000)
        post_thread(rest, nil, [tweet_id | acc])

      {:ok, %{"data" => data}} ->
        tweet_id = data["id"]
        if length(rest) > 0, do: Process.sleep(1000)
        post_thread(rest, nil, [tweet_id | acc])

      {:error, reason} ->
        {:error, {:partial_thread, Enum.reverse(acc), reason}}
    end
  end

  defp validate_tweets(tweets) when is_list(tweets) and length(tweets) >= 1 do
    invalid = Enum.find(tweets, fn t -> not is_binary(t) or String.length(t) == 0 or String.length(t) > 280 end)

    if invalid do
      {:error, "All tweets must be strings between 1 and 280 characters"}
    else
      {:ok, tweets}
    end
  end

  defp validate_tweets(_), do: {:error, "tweets must be a list of strings"}
end
