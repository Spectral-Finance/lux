defmodule Lux.Prisms.Twitter.CreateTweet do
  @moduledoc """
  A prism that creates a new tweet (or quote tweet/thread reply) using the Twitter v2 API.
  """
  use Lux.Prism,
    name: "Create Tweet",
    description: "Creates a new tweet on Twitter.",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "The text content of the tweet."
        },
        reply_to_tweet_id: %{
          type: :string,
          description: "If this is a reply, the ID of the tweet being replied to."
        },
        quote_tweet_id: %{
          type: :string,
          description: "If this is a quote tweet, the ID of the tweet being quoted."
        }
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string, description: "The ID of the created tweet"},
        text: %{type: :string, description: "The text of the created tweet"}
      }
    }

  alias Lux.Integrations.Twitter.Client

  @impl true
  def handler(params, _context) do
    text = Map.fetch!(params, "text")
    reply_to = Map.get(params, "reply_to_tweet_id")
    quote_id = Map.get(params, "quote_tweet_id")

    payload = %{"text" => text}

    payload =
      if reply_to do
        Map.put(payload, "reply", %{"in_reply_to_tweet_id" => reply_to})
      else
        payload
      end

    payload =
      if quote_id do
        Map.put(payload, "quote_tweet_id", quote_id)
      else
        payload
      end

    case Client.request(:post, "/tweets", %{json: payload}) do
      {:ok, %{"id" => _, "text" => _} = data} ->
        {:ok, data}

      {:ok, other} ->
        {:ok, other}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
