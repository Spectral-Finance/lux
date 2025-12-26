defmodule Lux.Lenses.Twitter.CreateTweet do
  @moduledoc """
  Lens for creating a Tweet (posting text, replies, or media).

  ## Examples
      Lux.Lenses.Twitter.CreateTweet.focus(%{text: "Hello from Lux!"})
  """
  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Create Tweet",
    description: "Post a new tweet to Twitter",
    url: "https://api.twitter.com/2/tweets",
    method: :post,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Tweet text (1-280 chars)"},
        reply: %{
          type: :object,
          properties: %{
            in_reply_to_tweet_id: %{type: :string}
          }
        },
        quote_tweet_id: %{type: :string, description: "Tweet ID to quote"},
        media: %{
          type: :object,
          properties: %{
            media_ids: %{type: :array, items: %{type: :string}}
          }
        }
      },
      required: ["text"]
    }

  @impl true
  def after_focus(%{"data" => data}) do
    {:ok,
     %{
       id: data["id"],
       text: data["text"],
       edit_history_tweet_ids: data["edit_history_tweet_ids"]
     }}
  end

  def after_focus(%{"errors" => errors}), do: {:error, errors}
  def after_focus(%{"title" => title, "detail" => detail}), do: {:error, "#{title}: #{detail}"}
  def after_focus(other), do: {:error, other}
end
