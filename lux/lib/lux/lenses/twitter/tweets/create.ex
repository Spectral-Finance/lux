defmodule Lux.Lenses.Twitter.Tweets.Create do
  @moduledoc """
  Creates a new Tweet on behalf of an authenticated user.

  ## Examples

      # Simple text tweet
      Lux.Lenses.Twitter.Tweets.Create.focus(%{
        text: "Hello from Lux AI agent! #buildinpublic"
      })

      # Tweet with media
      Lux.Lenses.Twitter.Tweets.Create.focus(%{
        text: "Check this out!",
        media: %{media_ids: ["1234567890"]}
      })

      # Reply to a tweet
      Lux.Lenses.Twitter.Tweets.Create.focus(%{
        text: "Great point!",
        reply: %{in_reply_to_tweet_id: "1234567890"}
      })
  """

  use Lux.Lens,
    name: "Twitter / Create Tweet",
    description: "Creates a new Tweet (post) on Twitter/X",
    url: "/2/tweets",
    method: :post,
    headers: [{"Content-Type", "application/json"}],
    auth: %{type: :custom, auth_function: &Lux.Integrations.Twitter.add_bearer_token/1},
    schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "The content of the Tweet. Max 4000 characters for Twitter Blue, 280 for regular users"
        },
        media: %{
          type: :object,
          description: "Media attachments",
          properties: %{
            media_ids: %{
              type: :array,
              items: %{type: :string},
              description: "Array of media IDs to attach (max 4)"
            },
            tagged_user_ids: %{
              type: :array,
              items: %{type: :string},
              description: "Array of user IDs to tag in the media"
            }
          }
        },
        reply: %{
          type: :object,
          description: "Reply settings",
          properties: %{
            in_reply_to_tweet_id: %{type: :string, description: "Tweet ID being replied to"},
            exclude_reply_user_ids: %{type: :array, items: %{type: :string}, description: "Users to exclude from reply thread"}
          }
        },
        quote_tweet_id: %{type: :string, description: "ID of the tweet being quoted"},
        for_super_followers_only: %{type: :boolean, description: "Limit to super followers only"}
      },
      required: ["text"]
    },
    transform: &__MODULE__.transform_response/1

  @doc false
  def transform_response(response) do
    case response do
      %{status: 201, body: %{"data" => %{"id" => id, "text" => text}}} ->
        {:ok, %{tweet_id: id, text: text, url: "https://twitter.com/i/web/status/#{id}"}}

      %{status: status, body: %{"errors" => errors}} when status in [401, 403, 429] ->
        {:error, %{status: status, errors: errors}}

      %{status: status, body: body} ->
        {:error, %{status: status, body: body}}
    end
  end
end
