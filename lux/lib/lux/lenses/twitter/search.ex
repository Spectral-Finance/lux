defmodule Lux.Lenses.Twitter.Search do
  @moduledoc """
  A lens that searches recent tweets using the Twitter v2 API.
  """
  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Twitter Search",
    description: "Searches for recent tweets matching a query.",
    url: "https://api.twitter.com/2/tweets/search/recent",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        query: %{
          type: :string,
          description: "The search query (e.g. 'crypto -is:retweet')"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of tweets to return (10-100)"
        }
      },
      required: ["query"]
    }

  def before_focus(params) do
    params
    |> Map.put_new("max_results", 10)
    |> Map.put("tweet.fields", "created_at,public_metrics,author_id")
  end

  @impl true
  def after_focus(%{"data" => data}) do
    {:ok, data}
  end

  def after_focus(%{"errors" => errors}) do
    {:error, errors}
  end

  def after_focus(other) do
    {:ok, other}
  end
end
