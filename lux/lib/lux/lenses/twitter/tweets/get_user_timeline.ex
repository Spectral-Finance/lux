defmodule Lux.Lenses.Twitter.Tweets.GetUserTimeline do
  @moduledoc """
  A lens for retrieving a user's tweet timeline from Twitter API v2.

  Returns tweets from a specific user in reverse chronological order.

  ## Examples

      iex> GetUserTimeline.focus(%{user_id: "123456789"})
      {:ok, %{tweets: [...], meta: %{...}}}

      iex> GetUserTimeline.focus(%{user_id: "123456789", max_results: 50})
      {:ok, %{tweets: [...], meta: %{...}}}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Get User Timeline",
    description: "Retrieves tweets from a specific user's timeline",
    url: "https://api.twitter.com/2/users/:user_id/tweets",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    params: %{
      "tweet.fields" => "id,text,author_id,created_at,public_metrics,referenced_tweets,entities",
      "expansions" => "author_id,attachments.media_keys",
      "user.fields" => "id,name,username,profile_image_url",
      "media.fields" => "media_key,type,url,preview_image_url",
      "max_results" => 10
    },
    schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :string,
          description: "The ID of the user whose timeline to retrieve"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of tweets (5-100)",
          minimum: 5,
          maximum: 100,
          default: 10
        },
        pagination_token: %{
          type: :string,
          description: "Pagination token for next page"
        },
        start_time: %{
          type: :string,
          description: "Start time in ISO 8601 format"
        },
        end_time: %{
          type: :string,
          description: "End time in ISO 8601 format"
        },
        exclude: %{
          type: :string,
          description: "Types to exclude (retweets, replies)",
          enum: ["retweets", "replies"]
        }
      },
      required: ["user_id"]
    }

  @doc """
  Transforms the Twitter API timeline response into a simpler format.
  """
  @impl true
  def before_focus(params) do
    params
    |> Map.put("user_id", params[:user_id] || params["user_id"])
    |> maybe_put("max_results", params[:max_results] || params["max_results"])
    |> maybe_put("pagination_token", params[:pagination_token] || params["pagination_token"])
    |> maybe_put("start_time", params[:start_time] || params["start_time"])
    |> maybe_put("end_time", params[:end_time] || params["end_time"])
    |> maybe_put("exclude", params[:exclude] || params["exclude"])
  end

  @impl true
  def after_focus(%{"data" => tweets} = response) do
    users = get_in(response, ["includes", "users"]) || []
    media = get_in(response, ["includes", "media"]) || []
    meta = response["meta"] || %{}

    formatted_tweets =
      Enum.map(tweets, fn tweet ->
        author = Enum.find(users, fn u -> u["id"] == tweet["author_id"] end)

        tweet_media =
          tweet
          |> get_in(["attachments", "media_keys"])
          |> List.wrap()
          |> Enum.map(fn key -> Enum.find(media, fn m -> m["media_key"] == key end) end)
          |> Enum.reject(&is_nil/1)

        %{
          id: tweet["id"],
          text: tweet["text"],
          author_id: tweet["author_id"],
          author: format_user(author),
          created_at: tweet["created_at"],
          metrics: tweet["public_metrics"],
          referenced_tweets: tweet["referenced_tweets"] || [],
          entities: tweet["entities"],
          media: Enum.map(tweet_media, &format_media/1)
        }
      end)

    {:ok,
     %{
       tweets: formatted_tweets,
       meta: %{
         result_count: meta["result_count"],
         newest_id: meta["newest_id"],
         oldest_id: meta["oldest_id"],
         next_token: meta["next_token"]
       }
     }}
  end

  def after_focus(%{"data" => nil, "meta" => meta}) do
    {:ok,
     %{
       tweets: [],
       meta: %{
         result_count: meta["result_count"] || 0,
         newest_id: nil,
         oldest_id: nil,
         next_token: nil
       }
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
      preview_image_url: media["preview_image_url"]
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
