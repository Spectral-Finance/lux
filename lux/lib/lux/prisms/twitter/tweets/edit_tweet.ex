defmodule Lux.Prisms.Twitter.Tweets.EditTweet do
  @moduledoc "Edits an X/Twitter post using the API v2 edit_options payload."

  use Lux.Prism,
    name: "Edit Twitter Post",
    description: "Creates an edit replacement for an existing X/Twitter post",
    input_schema: %{
      type: :object,
      properties: %{previous_tweet_id: %{type: :string}, text: %{type: :string}, access_token: %{type: :string}},
      required: ["previous_tweet_id", "text"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{previous_tweet_id: previous_id} = input, _context) do
    opts = Map.take(input, [:access_token, :bearer_token, :plug, :with_rate_limit])
    input |> Map.drop([:previous_tweet_id, :access_token, :bearer_token, :plug]) |> then(&Client.edit_tweet(previous_id, &1, opts))
  end

  def handler(_input, _context), do: {:error, "Missing previous_tweet_id"}
end
