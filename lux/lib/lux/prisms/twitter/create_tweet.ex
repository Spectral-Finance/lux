defmodule Lux.Prisms.Twitter.CreateTweet do
  @moduledoc """
  A prism for posting Tweets via Twitter API v2.
  """

  use Lux.Prism,
    name: "Post Tweet",
    description: "Posts a new tweet to Twitter",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "The content of the tweet"
        },
        reply_to_tweet_id: %{
          type: :string,
          description: "ID of the tweet to reply to (optional)"
        }
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        text: %{type: :string}
      }
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  def handler(params, agent) do
    text = params["text"] || params[:text]
    reply_id = params["reply_to_tweet_id"] || params[:reply_to_tweet_id]

    agent_name = agent[:name] || "Lux Agent"
    Logger.info("Agent #{agent_name} is posting a tweet")

    payload = %{text: text}
    
    # Agar bu javob (reply) bo'lsa, uni payloadga qo'shamiz
    payload = if reply_id do
      Map.put(payload, :reply, %{in_reply_to_tweet_id: reply_id})
    else
      payload
    end

    case Client.request(:post, "/tweets", json: payload) do
      {:ok, %{"data" => data}} ->
        Logger.info("Successfully posted tweet: #{data["id"]}")
        {:ok, %{id: data["id"], text: data["text"]}}

      {:error, reason} ->
        error_msg = "Failed to post tweet: #{inspect(reason)}"
        Logger.error(error_msg)
        {:error, error_msg}
    end
  end
end
