defmodule Lux.Lenses.Twitter.Tweets.CreateTweet do
  @moduledoc """
  A lens for creating tweets, quote tweets, replies, and media-attached posts
  via the Twitter API v2 (`/2/tweets`).

  ## Examples

      iex> CreateTweet.focus(%{
      ...>   "text" => "Launching autonomous agents on Lux!"
      ...> })
      {:ok, %{
        id: "1890000000000000001",
        text: "Launching autonomous agents on Lux!"
      }}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Create Tweet",
    description: "Creates a new tweet, quote tweet, or thread reply on Twitter/X",
    url: "https://api.twitter.com/2/tweets",
    method: :post,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "The text content of the tweet (up to 280 characters)"
        },
        quote_tweet_id: %{
          type: :string,
          description: "Optional ID of an existing tweet to quote"
        },
        reply: %{
          type: :object,
          description: "Optional reply configuration for thread creation (e.g. %{in_reply_to_tweet_id: id})"
        },
        media: %{
          type: :object,
          description: "Optional media attachment payload (e.g. %{media_ids: [id]})"
        }
      },
      required: ["text"]
    }

  @impl true
  def after_focus(%{"data" => %{"id" => id, "text" => text} = data}) do
    {:ok,
     %{
       id: id,
       text: text,
       edit_history_tweet_ids: Map.get(data, "edit_history_tweet_ids", [id])
     }}
  end

  def after_focus(%{"errors" => errors}) do
    {:error, %{"errors" => errors}}
  end

  def after_focus(error) do
    {:error, error}
  end
end
