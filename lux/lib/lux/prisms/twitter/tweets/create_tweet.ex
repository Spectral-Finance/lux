defmodule Lux.Prisms.Twitter.Tweets.CreateTweet do
  @moduledoc """
  Prism for creating tweets via Twitter API v2.

  Supports:
  - Simple text tweets
  - Tweets with media attachments
  - Quote tweets
  - Reply tweets
  - Polls

  ## Examples

      iex> CreateTweet.handler(%{"text" => "Hello from Lux!"}, ctx)
      {:ok, %{tweet_id: "123", text: "Hello from Lux!"}}

      iex> CreateTweet.handler(%{
      ...>   "text" => "Check this out",
      ...>   "quote_tweet_id" => "456"
      ...> }, ctx)
      {:ok, %{tweet_id: "789", text: "Check this out"}}
  """

  use Lux.Prism,
    name: "Create Tweet",
    description: "Creates a new tweet on Twitter/X",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Tweet text (max 280 chars)"},
        reply_to: %{type: :string, description: "Tweet ID to reply to"},
        quote_tweet_id: %{type: :string, description: "Tweet ID to quote"},
        media_ids: %{
          type: :array,
          items: %{type: :string},
          description: "Media IDs to attach (from upload)"
        },
        poll_options: %{
          type: :array,
          items: %{type: :string},
          description: "Poll options (2-4 choices)"
        },
        poll_duration_minutes: %{type: :integer, description: "Poll duration in minutes (5-10080)"}
      },
      required: ["text"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(params, _context) do
    body = build_tweet_body(params)

    case Client.request(:post, "/tweets", %{auth_type: :oauth1, json: body}) do
      {:ok, %{data: %{"id" => id, "text" => text}}} ->
        {:ok, %{tweet_id: id, text: text}}

      {:ok, %{data: %{"id" => id} = data}} ->
        {:ok, %{tweet_id: id, text: data["text"], data: data}}

      {:error, reason} ->
        {:error, "Failed to create tweet: #{inspect(reason)}"}
    end
  end

  defp build_tweet_body(params) do
    body = %{"text" => params["text"]}

    body =
      if params["reply_to"],
        do: Map.put(body, "reply", %{"in_reply_to_tweet_id" => params["reply_to"]}),
        else: body

    body =
      if params["quote_tweet_id"],
        do: Map.put(body, "quote_tweet_id", params["quote_tweet_id"]),
        else: body

    body =
      if params["media_ids"],
        do: Map.put(body, "media", %{"media_ids" => params["media_ids"]}),
        else: body

    body =
      if params["poll_options"] && length(params["poll_options"]) >= 2 do
        Map.put(body, "poll", %{
          "options" => Enum.map(params["poll_options"], &%{"label" => &1}),
          "duration_minutes" => params["poll_duration_minutes"] || 1440
        })
      else
        body
      end

    body
  end
end
