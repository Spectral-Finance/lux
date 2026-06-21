defmodule Lux.Prisms.Twitter.PostTweetPrism do
  @moduledoc """
  Prism for posting a tweet or a reply to X (Twitter).
  """

  use Lux.Prism,
    name: "Post Tweet",
    description: "Posts a new tweet or a reply to X (Twitter)",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "The content of the tweet",
          maxLength: 280
        },
        reply_to_tweet_id: %{
          type: :string,
          description: "The ID of the tweet to reply to (optional)"
        },
        dry_run: %{
          type: :boolean,
          description: "If true, logs the tweet instead of posting it (defaults to true for safety)",
          default: true
        }
      },
      required: ["text"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  def handler(input, _ctx) do
    # Default to true if not explicitly set to false, or if env var is set
    dry_run = Map.get(input, :dry_run, true) or System.get_env("TWITTER_DRY_RUN") == "true"

    payload = %{text: input[:text]}

    payload =
      if id = input[:reply_to_tweet_id] do
        Map.put(payload, :reply, %{in_reply_to_tweet_id: id})
      else
        payload
      end

    if dry_run do
      Logger.info("[Twitter Dry Run] Would have posted: #{inspect(payload)}")
      {:ok, %{"data" => %{"id" => "dry_run_#{Lux.UUID.generate()}", "text" => input[:text]}, "dry_run" => true}}
    else
      Client.request(:post, "/tweets", %{json: payload})
    end
  end
end
