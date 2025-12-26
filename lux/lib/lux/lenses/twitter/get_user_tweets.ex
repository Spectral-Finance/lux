defmodule Lux.Lenses.Twitter.GetUserTweets do
  @moduledoc """
  Lens for retrieving a list of Tweets from a specific User.

  ## Examples
      Lux.Lenses.Twitter.GetUserTweets.focus(%{id: "2244994945", max_results: 20})
  """
  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Get User Tweets",
    description: "Retrieve tweets posted by a specific user",
    url: "https://api.twitter.com/2/users/:id/tweets",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        id: %{type: :string, description: "The ID of the user"},
        max_results: %{
          type: :integer,
          minimum: 5,
          maximum: 100,
          description: "Number of results (default 10)"
        },
        pagination_token: %{type: :string, description: "Token for next page"}
      },
      required: ["id"]
    }

  @impl true
  def after_focus(%{"data" => data, "meta" => meta}) do
    {:ok,
     %{
       tweets: data,
       next_token: meta["next_token"]
     }}
  end

  def after_focus(%{"data" => data}) do
    {:ok, %{tweets: data, next_token: nil}}
  end

  def after_focus(%{"errors" => errors}), do: {:error, errors}
  def after_focus(%{"title" => title, "detail" => detail}), do: {:error, "#{title}: #{detail}"}
  def after_focus(other), do: {:error, other}
end
