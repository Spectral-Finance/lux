defmodule Lux.Lenses.Twitter.GetTimeline do
  @moduledoc """
  A lens that fetches the home timeline (or user timeline) using the Twitter v2 API.
  """
  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Twitter Timeline Reader",
    description: "Reads the timeline of tweets for a given user.",
    url: "https://api.twitter.com/2/users/:user_id/tweets",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :string,
          description: "The numerical Twitter User ID to fetch the timeline for"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of tweets to return (10-100)"
        }
      },
      required: ["user_id"]
    }

  def before_focus(params) do
    # Assign defaults for params so it's handled properly by the API
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
