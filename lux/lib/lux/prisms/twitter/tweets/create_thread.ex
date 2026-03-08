defmodule Lux.Prisms.Twitter.Tweets.CreateThread do
  @moduledoc """
  Prism for creating tweet threads (tweetstorms) via Twitter API v2.

  Creates multiple tweets in sequence, each replying to the previous one.

  ## Examples

      iex> CreateThread.handler(%{
      ...>   "tweets" => ["First tweet", "Second tweet", "Final tweet"]
      ...> }, ctx)
      {:ok, %{thread_ids: ["1", "2", "3"], count: 3}}
  """

  use Lux.Prism,
    name: "Create Thread",
    description: "Creates a tweet thread (multiple connected tweets)",
    input_schema: %{
      type: :object,
      properties: %{
        tweets: %{
          type: :array,
          items: %{type: :string},
          description: "List of tweet texts for the thread (in order)"
        }
      },
      required: ["tweets"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{"tweets" => tweets}, _context) when is_list(tweets) and length(tweets) > 0 do
    case create_thread(tweets, nil, []) do
      {:ok, ids} ->
        {:ok, %{thread_ids: Enum.reverse(ids), count: length(ids)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def handler(_, _), do: {:error, "tweets must be a non-empty list of strings"}

  defp create_thread([], _reply_to, acc), do: {:ok, acc}

  defp create_thread([text | rest], reply_to, acc) do
    body =
      if reply_to do
        %{"text" => text, "reply" => %{"in_reply_to_tweet_id" => reply_to}}
      else
        %{"text" => text}
      end

    case Client.request(:post, "/tweets", %{auth_type: :oauth1, json: body}) do
      {:ok, %{data: %{"id" => id}}} ->
        create_thread(rest, id, [id | acc])

      {:error, reason} ->
        {:error, "Thread creation failed at tweet #{length(acc) + 1}: #{inspect(reason)}"}
    end
  end
end
