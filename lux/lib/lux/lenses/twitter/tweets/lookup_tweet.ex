defmodule Lux.Lenses.Twitter.Tweets.LookupTweet do
  @moduledoc """
  A lens for looking up tweets by ID via the Twitter/X API v2.

  Supports fetching tweets with optional expansions for author, referenced tweets, and attachments.

  ## Examples

      iex> LookupTweet.focus(%{id: "123456789"})
      {:ok, %{data: %{id: "123456789", text: "Hello world"}}}

      iex> LookupTweet.focus(%{id: "123456789", expansions: ["author_id"]})
      {:ok, %{data: %{id: "...", text: "..."}, includes: %{users: [...]}}}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Lookup Tweet",
    description: "Fetches a tweet by its ID",
    url: "#{Twitter.base_url()}/tweets/:id",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        id: %{
          type: :string,
          description: "The ID of the tweet to fetch"
        },
        expansions: %{
          type: :array,
          description: "Expansion fields to include (author_id, referenced_tweets.id, attachments.media_keys, etc.)",
          items: %{type: :string}
        },
        tweet_fields: %{
          type: :array,
          description: "Additional tweet fields to return (created_at, public_metrics, etc.)",
          items: %{type: :string}
        }
      },
      required: ["id"]
    }

  def after_focus(%{"data" => data} = body) do
    result = %{data: data}

    result =
      case Map.get(body, "includes") do
        nil -> result
        includes -> Map.put(result, :includes, includes)
      end

    {:ok, result}
  end

  def after_focus(%{"errors" => errors}) do
    {:error, errors}
  end

  def after_focus(body) do
    {:error, %{error: "Unexpected response", raw: body}}
  end
end
