defmodule Lux.Lenses.Twitter.Tweets.CreateTweet do
  @moduledoc """
  A lens for publishing tweets via the Twitter API v2.

  ## Examples

      iex> CreateTweet.focus(%{text: "Hello from Lux agent framework!"})
      {:ok, %{
        id: "1234567890",
        text: "Hello from Lux agent framework!"
      }}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Create Twitter Tweet",
    description: "Publishes a new tweet on Twitter (X)",
    url: "https://api.twitter.com/2/tweets",
    method: :post,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "The text content of the tweet (up to 280 characters for standard accounts)",
          maxLength: 280
        },
        quote_tweet_id: %{
          type: :string,
          description: "Optional tweet ID to quote"
        },
        reply_to_tweet_id: %{
          type: :string,
          description: "Optional tweet ID to reply to"
        }
      },
      required: ["text"]
    }

  @doc """
  Transforms outgoing request payload.
  """
  @impl true
  def before_focus(params) do
    payload = %{"text" => params.text}

    payload =
      if Map.get(params, :quote_tweet_id) do
        Map.put(payload, "quote_tweet_id", to_string(params.quote_tweet_id))
      else
        payload
      end

    payload =
      if Map.get(params, :reply_to_tweet_id) do
        Map.put(payload, "reply", %{"in_reply_to_tweet_id" => to_string(params.reply_to_tweet_id)})
      else
        payload
      end

    {:ok, payload}
  end

  @doc """
  Transforms the Twitter API response into a standard format.
  """
  @impl true
  def after_focus(%{"data" => %{"id" => id, "text" => text}} = response) do
    {:ok,
     %{
       id: id,
       text: text,
       raw: response
     }}
  end

  def after_focus(%{"data" => data}) do
    {:ok, data}
  end

  def after_focus(other), do: {:ok, other}
end
