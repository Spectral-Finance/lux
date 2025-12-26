defmodule Lux.Lenses.Twitter.QuoteTweet do
  @moduledoc """
  Lens for Quoting a Tweet. This is a wrapper around CreateTweet requiring quote_tweet_id.

  ## Examples
      Lux.Lenses.Twitter.QuoteTweet.focus(%{text: "Check this out!", quote_tweet_id: "12345"})
  """
  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Quote Tweet",
    description: "Post a new tweet quoting another tweet",
    url: "https://api.twitter.com/2/tweets",
    method: :post,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Commentary text"},
        quote_tweet_id: %{type: :string, description: "Tweet ID to quote"}
      },
      required: ["text", "quote_tweet_id"]
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
