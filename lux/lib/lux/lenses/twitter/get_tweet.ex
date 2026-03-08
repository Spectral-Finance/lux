defmodule Lux.Lenses.Twitter.GetTweet do
  @moduledoc """
  Lens for fetching tweet details via Twitter API v2.

  Retrieves a single tweet by ID with configurable expansions and fields.

  ## Examples

      iex> GetTweet.focus(%{tweet_id: "123456"})
      {:ok, %{id: "123456", text: "Hello!", author_id: "789", ...}}
  """

  use Lux.Lens,
    name: "Get Tweet",
    description: "Fetches a tweet by ID from Twitter API v2",
    url: "https://api.twitter.com/2/tweets/:id",
    method: :get,
    headers: [{"Content-Type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Lux.Integrations.Twitter.add_auth_header/1
    },
    schema: %{
      type: :object,
      properties: %{
        tweet_id: %{type: :string, description: "Tweet ID to fetch"},
        expansions: %{
          type: :string,
          description: "Comma-separated expansions (e.g., author_id,attachments.media_keys)"
        },
        tweet_fields: %{
          type: :string,
          description: "Comma-separated tweet fields"
        },
        user_fields: %{
          type: :string,
          description: "Comma-separated user fields"
        }
      },
      required: ["tweet_id"]
    }

  alias Lux.Integrations.Twitter.Client

  @default_tweet_fields "id,text,author_id,created_at,public_metrics,conversation_id,in_reply_to_user_id,lang"
  @default_expansions "author_id,attachments.media_keys"

  @impl true
  def before_focus(params) do
    tweet_id = params[:tweet_id] || params["tweet_id"]

    query_params = %{
      "tweet.fields" => params[:tweet_fields] || @default_tweet_fields,
      "expansions" => params[:expansions] || @default_expansions
    }

    query_params =
      if params[:user_fields],
        do: Map.put(query_params, "user.fields", params[:user_fields]),
        else: query_params

    %{
      url: "https://api.twitter.com/2/tweets/#{tweet_id}",
      params: query_params
    }
  end

  @impl true
  def after_focus(%{"data" => data, "includes" => includes}) do
    {:ok, format_tweet(data, includes)}
  end

  def after_focus(%{"data" => data}) do
    {:ok, format_tweet(data, %{})}
  end

  def after_focus(%{"errors" => [%{"detail" => detail} | _]}) do
    {:error, detail}
  end

  def after_focus(other), do: {:error, "Unexpected response: #{inspect(other)}"}

  defp format_tweet(data, includes) do
    author =
      case includes do
        %{"users" => [user | _]} -> %{id: user["id"], name: user["name"], username: user["username"]}
        _ -> nil
      end

    metrics = data["public_metrics"] || %{}

    %{
      id: data["id"],
      text: data["text"],
      author_id: data["author_id"],
      author: author,
      created_at: data["created_at"],
      conversation_id: data["conversation_id"],
      language: data["lang"],
      metrics: %{
        likes: metrics["like_count"] || 0,
        retweets: metrics["retweet_count"] || 0,
        replies: metrics["reply_count"] || 0,
        quotes: metrics["quote_count"] || 0,
        impressions: metrics["impression_count"] || 0
      }
    }
  end
end
