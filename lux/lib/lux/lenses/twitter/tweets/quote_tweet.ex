defmodule Lux.Lenses.Twitter.Tweets.QuoteTweet do
  @moduledoc """
  A lens for quoting an existing tweet via the Twitter/X API v2.

  Creates a new tweet with a link to the quoted tweet embedded.

  ## Examples

      iex> QuoteTweet.focus(%{
      ...>   text: "Great take!",
      ...>   quoted_tweet_id: "123456789"
      ...> })
      {:ok, %{data: %{id: "...", text: "Great take!"}}}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Quote Tweet",
    description: "Creates a quote tweet referencing an existing tweet",
    url: "#{Twitter.base_url()}/tweets",
    method: :post,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "The comment text for the quote tweet"
        },
        quoted_tweet_id: %{
          type: :string,
          description: "The ID of the tweet being quoted"
        },
        media: %{
          type: :object,
          description: "Media to attach to the quote tweet",
          properties: %{
            media_ids: %{
              type: :array,
              items: %{type: :string}
            }
          }
        }
      },
      required: ["text", "quoted_tweet_id"]
    }

  def after_focus(%{"data" => data}) do
    {:ok, data}
  end

  def after_focus(%{"errors" => errors}) do
    {:error, errors}
  end

  def after_focus(body) do
    {:error, %{error: "Unexpected response", raw: body}}
  end
end
