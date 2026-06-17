defmodule Lux.Lenses.Twitter.Tweets.GetTweet do
  @moduledoc """
  A lens for retrieving a single tweet by its ID from Twitter API v2.

  Returns full tweet data including metrics, author info, and optional expansions.

  ## Examples

      iex> GetTweet.focus(%{tweet_id: "1234567890"})
      {:ok, %{
        id: "1234567890",
        text: "Hello, Twitter!",
        author_id: "9876543210",
        created_at: "2024-01-01T00:00:00.000Z",
        metrics: %{...}
      }}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Get Tweet",
    description: "Retrieves a single tweet by ID with full metadata",
    url: "https://api.twitter.com/2/tweets/:tweet_id",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    params: %{
      "tweet.fields" => "id,text,author_id,created_at,public_metrics,referenced_tweets,entities,attachments",
      "expansions" => "author_id,attachments.media_keys",
      "user.fields" => "id,name,username,profile_image_url",
      "media.fields" => "media_key,type,url,preview_image_url,alt_text"
    },
    schema: %{
      type: :object,
      properties: %{
        tweet_id: %{
          type: :string,
          description: "The ID of the tweet to retrieve"
        },
        tweet_fields: %{
          type: :string,
          description: "Comma-separated list of tweet fields to include",
          default: "id,text,author_id,created_at,public_metrics,referenced_tweets"
        },
        expansions: %{
          type: :string,
          description: "Comma-separated list of expansions",
          default: "author_id"
        }
      },
      required: ["tweet_id"]
    }

  @doc """
  Transforms the Twitter API response into a simpler format.
  """
  @impl true
  def after_focus(%{"data" => tweet} = response) do
    users = get_in(response, ["includes", "users"]) || []
    media = get_in(response, ["includes", "media"]) || []

    author = Enum.find(users, fn u -> u["id"] == tweet["author_id"] end)

    {:ok,
     %{
       id: tweet["id"],
       text: tweet["text"],
       author_id: tweet["author_id"],
       author: format_user(author),
       created_at: tweet["created_at"],
       metrics: tweet["public_metrics"],
       referenced_tweets: tweet["referenced_tweets"] || [],
       entities: tweet["entities"],
       attachments: tweet["attachments"],
       media: Enum.map(media, &format_media/1)
     }}
  end

  def after_focus(%{"errors" => errors}) do
    {:error, %{errors: errors}}
  end

  def after_focus(%{"title" => title, "detail" => detail}) do
    {:error, %{title: title, detail: detail}}
  end

  defp format_user(nil), do: nil

  defp format_user(user) do
    %{
      id: user["id"],
      name: user["name"],
      username: user["username"],
      profile_image_url: user["profile_image_url"]
    }
  end

  defp format_media(media) do
    %{
      media_key: media["media_key"],
      type: media["type"],
      url: media["url"],
      preview_image_url: media["preview_image_url"],
      alt_text: media["alt_text"]
    }
  end
end
