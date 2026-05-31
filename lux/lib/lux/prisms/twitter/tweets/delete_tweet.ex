defmodule Lux.Prisms.Twitter.Tweets.DeleteTweet do
  @moduledoc "Deletes an X/Twitter post by ID."

  use Lux.Prism,
    name: "Delete Twitter Post",
    description: "Deletes a post through X/Twitter API v2",
    input_schema: %{
      type: :object,
      properties: %{tweet_id: %{type: :string}, access_token: %{type: :string}},
      required: ["tweet_id"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{tweet_id: tweet_id} = input, _context) do
    Client.delete_tweet(tweet_id, Map.take(input, [:access_token, :bearer_token, :plug, :with_rate_limit]))
  end

  def handler(_input, _context), do: {:error, "Missing tweet_id"}
end
