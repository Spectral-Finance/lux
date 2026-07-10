defmodule Lux.Prisms.Twitter.QuoteTweet do
  @moduledoc """
  A prism for quoting a tweet via the Twitter API v2.
  """
  use Lux.Prism,
    name: "Quote Tweet",
    description: "Quotes an existing tweet on behalf of the authenticated user.",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "The text of the quote tweet"},
        quote_tweet_id: %{type: :string, description: "The ID of the tweet to quote"}
      },
      required: ["text", "quote_tweet_id"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(input, _ctx) do
    text = Map.get(input, "text") || Map.get(input, :text)
    quote_id = Map.get(input, "quote_tweet_id") || Map.get(input, :quote_tweet_id)
    
    Client.quote_tweet(quote_id, text)
  end
end
