defmodule Lux.Lenses.Twitter.DeleteTweet do
  @moduledoc """
  Lens for deleting a Tweet by ID.

  ## Examples
      Lux.Lenses.Twitter.DeleteTweet.focus(%{id: "1234567890"})
  """
  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Delete Tweet",
    description: "Delete a tweet specified by ID",
    url: "https://api.twitter.com/2/tweets/:id",
    method: :delete,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        id: %{type: :string, description: "The ID of the tweet to delete"}
      },
      required: ["id"]
    }

  @impl true
  def after_focus(%{"data" => %{"deleted" => deleted}}) do
    {:ok, %{deleted: deleted}}
  end

  def after_focus(%{"errors" => errors}), do: {:error, errors}
  def after_focus(%{"title" => title, "detail" => detail}), do: {:error, "#{title}: #{detail}"}
  def after_focus(other), do: {:error, other}
end
