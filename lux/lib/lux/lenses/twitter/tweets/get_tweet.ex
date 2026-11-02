defmodule Lux.Lenses.Twitter.Tweets.GetTweet do
  @moduledoc """
  A lens for retrieving a tweet by ID via Twitter API v2.
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Get Twitter Tweet",
    description: "Retrieves a tweet and its metrics by ID",
    url: "https://api.twitter.com/2/tweets/:tweet_id",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        tweet_id: %{
          type: :string,
          description: "The ID of the tweet to retrieve"
        }
      },
      required: ["tweet_id"]
    }

  @impl true
  def after_focus(%{"data" => tweet}) do
    {:ok, tweet}
  end

  def after_focus(other), do: {:ok, other}
end
