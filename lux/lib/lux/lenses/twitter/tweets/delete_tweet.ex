defmodule Lux.Lenses.Twitter.Tweets.DeleteTweet do
  @moduledoc """
  A lens for deleting tweets via the Twitter/X API v2.

  ## Examples

      iex> DeleteTweet.focus(%{id: "123456789"})
      {:ok, %{deleted: true}}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Delete Tweet",
    description: "Deletes a tweet by ID",
    url: "#{Twitter.base_url()}/tweets/:id",
    method: :delete,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        id: %{
          type: :string,
          description: "The ID of the tweet to delete"
        }
      },
      required: ["id"]
    }

  def after_focus(%{"data" => %{"deleted" => deleted}}) do
    {:ok, %{deleted: deleted}}
  end

  def after_focus(%{"errors" => errors}) do
    {:error, errors}
  end

  def after_focus(body) do
    {:error, %{error: "Unexpected response", raw: body}}
  end
end
