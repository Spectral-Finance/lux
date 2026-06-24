defmodule Lux.Prisms.Twitter.DeleteTweet do
  @moduledoc """
  A prism for deleting a tweet via the Twitter API v2.
  """
  use Lux.Prism,
    name: "Delete Tweet",
    description: "Deletes a tweet by its ID.",
    input_schema: %{
      type: :object,
      properties: %{
        tweet_id: %{type: :string, description: "The ID of the tweet to delete"}
      },
      required: ["tweet_id"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(input, _ctx) do
    tweet_id = Map.get(input, "tweet_id") || Map.get(input, :tweet_id)
    Client.delete_tweet(tweet_id)
  end
end
