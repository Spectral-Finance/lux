defmodule Lux.Prisms.Twitter.Tweets.CreateTweet do
  @moduledoc "Creates an X/Twitter post, including replies, quote posts, media, and edit payloads."

  use Lux.Prism,
    name: "Create Twitter Post",
    description: "Creates a post through X/Twitter API v2",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, minLength: 1, maxLength: 280},
        reply_to_tweet_id: %{type: :string},
        quote_tweet_id: %{type: :string},
        media_ids: %{type: :array, items: %{type: :string}},
        access_token: %{type: :string}
      },
      required: ["text"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(input, _context) do
    opts = take_opts(input)
    input |> Map.drop([:access_token, :bearer_token, :plug]) |> Client.create_tweet(opts)
  end

  defp take_opts(input), do: Map.take(input, [:access_token, :bearer_token, :plug, :with_rate_limit])
end
