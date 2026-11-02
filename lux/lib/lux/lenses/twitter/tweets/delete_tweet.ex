defmodule Lux.Lenses.Twitter.Tweets.DeleteTweet do
  @moduledoc """
  A lens for deleting a tweet by ID via Twitter API v2.
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Delete Twitter Tweet",
    description: "Deletes a tweet by ID",
    url: "https://api.twitter.com/2/tweets/:tweet_id",
    method: :delete,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        tweet_id: %{
          type: :string,
          description: "The ID of the tweet to delete"
        }
      },
      required: ["tweet_id"]
    }

  @doc """
  Transforms the deletion response.
  """
  @impl true
  def after_focus(%{"data" => %{"deleted" => true}}) do
    {:ok, %{deleted: true}}
  end

  def after_focus(%{"data" => data}) do
    {:ok, data}
  end

  def after_focus(other), do: {:ok, other}
end
