defmodule Lux.Lenses.Twitter.GetTweet do
  @moduledoc """
  Lens for retrieving a single Tweet by ID.

  ## Examples
      Lux.Lenses.Twitter.GetTweet.focus(%{id: "1234567890", "tweet.fields": "created_at,author_id"})
  """
  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Get Tweet",
    description: "Retrieve a single tweet object with optional fields",
    url: "https://api.twitter.com/2/tweets/:id",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        id: %{type: :string, description: "The ID of the tweet"},
        "tweet.fields": %{type: :string, description: "Comma-separated list of fields"},
        expansions: %{type: :string, description: "Comma-separated list of expansions"}
      },
      required: ["id"]
    }

  @impl true
  def after_focus(%{"data" => data}) do
    {:ok,
     %{
       id: data["id"],
       text: data["text"],
       author_id: data["author_id"],
       created_at: data["created_at"]
     }}
  end

  def after_focus(%{"errors" => errors}), do: {:error, errors}
  def after_focus(%{"title" => title, "detail" => detail}), do: {:error, "#{title}: #{detail}"}
  def after_focus(other), do: {:error, other}
end
