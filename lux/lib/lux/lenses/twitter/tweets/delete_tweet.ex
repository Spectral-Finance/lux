defmodule Lux.Lenses.Twitter.Tweets.DeleteTweet do
  @moduledoc """
  A lens for deleting a tweet by ID via the Twitter API v2 (`/2/tweets/:id`).

  ## Examples

      iex> DeleteTweet.focus(%{"id" => "1890000000000000001"})
      {:ok, %{deleted: true}}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Delete Tweet",
    description: "Deletes a tweet by its unique ID on Twitter/X",
    url: "https://api.twitter.com/2/tweets/:id",
    method: :delete,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        id: %{
          type: :string,
          description: "The unique ID of the tweet to delete"
        }
      },
      required: ["id"]
    }

  @impl true
  def after_focus(%{"data" => %{"deleted" => deleted}}) do
    {:ok, %{deleted: deleted}}
  end

  def after_focus(%{"errors" => errors}) do
    {:error, %{"errors" => errors}}
  end

  def after_focus(error) do
    {:error, error}
  end
end
