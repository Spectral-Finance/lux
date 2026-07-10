defmodule Lux.Prisms.Twitter.CreateTweet do
  @moduledoc """
  A prism for creating a tweet via the Twitter API v2.
  """
  use Lux.Prism,
    name: "Create Tweet",
    description: "Posts a new tweet on behalf of the authenticated user.",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "The text of the tweet"},
        reply_to_tweet_id: %{type: :string, description: "Optional ID of a tweet to reply to"},
        quote_tweet_id: %{type: :string, description: "Optional ID of a tweet to quote"}
      },
      required: ["text"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(input, _ctx) do
    text = Map.get(input, "text") || Map.get(input, :text)
    reply_to = Map.get(input, "reply_to_tweet_id") || Map.get(input, :reply_to_tweet_id)
    quote_tweet = Map.get(input, "quote_tweet_id") || Map.get(input, :quote_tweet_id)

    opts = %{}
    opts = if reply_to, do: Map.put(opts, :reply, %{in_reply_to_tweet_id: reply_to}), else: opts
    opts = if quote_tweet, do: Map.put(opts, :quote_tweet_id, quote_tweet), else: opts

    Client.create_tweet(text, opts)
  end
end
