defmodule Lux.Prisms.Twitter.EditTweet do
  @moduledoc """
  A prism for editing a tweet via the Twitter API v2.
  """
  use Lux.Prism,
    name: "Edit Tweet",
    description: "Edits an existing tweet. Note: This API is only available to specific verified accounts.",
    input_schema: %{
      type: :object,
      properties: %{
        tweet_id: %{type: :string, description: "The ID of the tweet to edit"},
        text: %{type: :string, description: "The new text for the tweet"}
      },
      required: ["tweet_id", "text"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(input, _ctx) do
    tweet_id = Map.get(input, "tweet_id") || Map.get(input, :tweet_id)
    text = Map.get(input, "text") || Map.get(input, :text)
    
    Client.edit_tweet(tweet_id, text)
  end
end
