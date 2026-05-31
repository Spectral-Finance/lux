defmodule Lux.Prisms.Twitter.Tweets.QuoteTweet do
  @moduledoc "Creates a quote post for an existing X/Twitter post."

  use Lux.Prism,
    name: "Quote Twitter Post",
    description: "Creates a quote post through X/Twitter API v2",
    input_schema: %{
      type: :object,
      properties: %{text: %{type: :string}, quoted_tweet_id: %{type: :string}, access_token: %{type: :string}},
      required: ["text", "quoted_tweet_id"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{text: text, quoted_tweet_id: quoted_id} = input, _context) do
    Client.quote_tweet(text, quoted_id, Map.take(input, [:access_token, :bearer_token, :plug, :with_rate_limit]))
  end

  def handler(_input, _context), do: {:error, "Missing text or quoted_tweet_id"}
end
