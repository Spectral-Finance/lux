defmodule Lux.Lenses.Twitter.Tweets.CreateTweet do
  @moduledoc """
  A lens for creating tweets via the Twitter/X API v2.

  Supports text-only tweets, reply tweets, quote tweets, and polls.

  ## Examples

      iex> CreateTweet.focus(%{text: "Hello from Lux!"})
      {:ok, %{data: %{id: "123456789", text: "Hello from Lux!"}}}

      iex> CreateTweet.focus(%{
      ...>   text: "Replying to a tweet",
      ...>   reply: %{in_reply_to_tweet_id: "987654321"}
      ...> })
      {:ok, %{data: %{id: "..."}}}

      iex> CreateTweet.focus(%{
      ...>   text: "Join the discussion",
      ...>   poll: %{
      ...>     options: ["Yes", "No", "Maybe"],
      ...>     duration_minutes: 120
      ...>   }
      ...> })
      {:ok, %{data: %{id: "..."}}}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Create Tweet",
    description: "Creates a new tweet on Twitter/X",
    url: "#{Twitter.base_url()}/tweets",
    method: :post,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "The content of the tweet (max 280 characters for most users, 4000 for X Premium)"
        },
        reply: %{
          type: :object,
          description: "Reply settings for the tweet",
          properties: %{
            in_reply_to_tweet_id: %{
              type: :string,
              description: "The ID of the tweet being replied to"
            },
            exclude_reply_user_ids: %{
              type: :array,
              description: "User IDs to exclude from the reply thread",
              items: %{type: :string}
            }
          }
        },
        poll: %{
          type: :object,
          description: "Poll attached to the tweet",
          properties: %{
            options: %{
              type: :array,
              description: "List of poll options (min 2, max 4)",
              items: %{type: :string},
              minItems: 2,
              maxItems: 4
            },
            duration_minutes: %{
              type: :integer,
              description: "Duration of the poll in minutes (min 5, max 10080)",
              minimum: 5,
              maximum: 10080
            }
          }
        },
        media: %{
          type: :object,
          description: "Media to attach to the tweet",
          properties: %{
            media_ids: %{
              type: :array,
              description: "List of media IDs to attach (max 4)",
              items: %{type: :string},
              maxItems: 4
            },
            tagged_user_ids: %{
              type: :array,
              description: "User IDs to tag in the media",
              items: %{type: :string}
            }
          }
        }
      },
      required: ["text"]
    }

  def after_focus(%{"data" => data} = _body) do
    {:ok, data}
  end

  def after_focus(%{"errors" => errors}) do
    {:error, errors}
  end

  def after_focus(body) do
    {:error, %{error: "Unexpected response", raw: body}}
  end
end
