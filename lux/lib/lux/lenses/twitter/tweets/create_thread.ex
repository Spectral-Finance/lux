defmodule Lux.Lenses.Twitter.Tweets.CreateThread do
  @moduledoc """
  A lens for creating a tweet thread via the Twitter/X API v2.

  Creates multiple tweets where each subsequent tweet replies to the previous one,
  forming a connected thread.

  ## Examples

      iex> CreateThread.focus(%{
      ...>   tweets: [
      ...>     %{text: "Tweet 1 of the thread"},
      ...>     %{text: "Tweet 2 of the thread"},
      ...>     %{text: "Tweet 3 of the thread"}
      ...>   ]
      ...> })
      {:ok, [%{id: "...", text: "Tweet 1 of the thread"}, ...]}
  """

  use Lux.Lens,
    name: "Create Tweet Thread",
    description: "Creates a connected thread of tweets",
    url: "",
    method: :post,
    schema: %{
      type: :object,
      properties: %{
        tweets: %{
          type: :array,
          description: "List of tweets to post as a thread (min 2)",
          items: %{
            type: :object,
            properties: %{
              text: %{
                type: :string,
                description: "The content of the tweet"
              },
              media: %{
                type: :object,
                description: "Media attachments for this tweet",
                properties: %{
                  media_ids: %{
                    type: :array,
                    items: %{type: :string}
                  }
                }
              },
              poll: %{
                type: :object,
                description: "Poll for this tweet",
                properties: %{
                  options: %{type: :array, items: %{type: :string}},
                  duration_minutes: %{type: :integer}
                }
              }
            },
            required: ["text"]
          },
          minItems: 2
        }
      },
      required: ["tweets"]
    }

  def after_focus(result) do
    {:ok, result}
  end

  def focus(%{tweets: tweets}, _opts) do
    alias Lux.Lenses.Twitter.Tweets.CreateTweet

    result =
      tweets
      |> Enum.reduce({:ok, [], nil}, fn
        tweet, {:ok, acc, nil} ->
          case CreateTweet.focus(%{text: tweet.text}) do
            {:ok, created} -> {:ok, [created | acc], created["id"]}
            error -> error
          end

        tweet, {:ok, acc, last_id} ->
          params =
            %{text: tweet.text}
            |> Map.put(:reply, %{in_reply_to_tweet_id: last_id})
            |> then(fn p ->
              if tweet[:media], do: Map.put(p, :media, tweet.media), else: p
            end)
            |> then(fn p ->
              if tweet[:poll], do: Map.put(p, :poll, tweet.poll), else: p
            end)

          case CreateTweet.focus(params) do
            {:ok, created} -> {:ok, [created | acc], created["id"]}
            error -> error
          end

        _, error, _ ->
          error
      end)
      |> case do
        {:ok, tweets, _} -> {:ok, Enum.reverse(tweets)}
        error -> error
      end

    result
  end
end
