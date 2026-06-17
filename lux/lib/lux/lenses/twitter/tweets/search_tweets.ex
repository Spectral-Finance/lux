defmodule Lux.Lenses.Twitter.Tweets.SearchTweets do
  @moduledoc """
  A lens for searching recent tweets using Twitter API v2.

  Supports full-text search with operators, pagination, and result filtering.

  ## Search Operators

  - `"exact phrase"` - Exact phrase match
  - `from:username` - Tweets from a specific user
  - `to:username` - Tweets to a specific user
  - `is:retweet` - Only retweets
  - `is:reply` - Only replies
  - `has:media` - Tweets with media
  - `has:links` - Tweets with links
  - `lang:en` - Language filter

  ## Examples

      iex> SearchTweets.focus(%{query: "elixir lang:en"})
      {:ok, %{tweets: [...], meta: %{...}}}

      iex> SearchTweets.focus(%{query: "from:elixirlang", max_results: 100})
      {:ok, %{tweets: [...], meta: %{...}}}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Search Tweets",
    description: "Searches recent tweets matching a query",
    url: "https://api.twitter.com/2/tweets/search/recent",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    params: %{
      "tweet.fields" => "id,text,author_id,created_at,public_metrics,referenced_tweets",
      "expansions" => "author_id",
      "user.fields" => "id,name,username,profile_image_url",
      "max_results" => 10
    },
    schema: %{
      type: :object,
      properties: %{
        query: %{
          type: :string,
          description: "Search query string",
          minLength: 1,
          maxLength: 512
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of results (10-100)",
          minimum: 10,
          maximum: 100,
          default: 10
        },
        next_token: %{
          type: :string,
          description: "Pagination token for next page of results"
        },
        start_time: %{
          type: :string,
          description: "Start time in ISO 8601 format (YYYY-MM-DDTHH:mm:ssZ)"
        },
        end_time: %{
          type: :string,
          description: "End time in ISO 8601 format (YYYY-MM-DDTHH:mm:ssZ)"
        },
        sort_order: %{
          type: :string,
          description: "Sort order for results",
          enum: ["recency", "relevancy"]
        }
      },
      required: ["query"]
    }

  @doc """
  Transforms the Twitter API search response into a simpler format.
  """
  @impl true
  def before_focus(params) do
    # Map schema params to API params
    params
    |> Map.put("query", params[:query] || params["query"])
    |> maybe_put("max_results", params[:max_results] || params["max_results"])
    |> maybe_put("next_token", params[:next_token] || params["next_token"])
    |> maybe_put("start_time", params[:start_time] || params["start_time"])
    |> maybe_put("end_time", params[:end_time] || params["end_time"])
    |> maybe_put("sort_order", params[:sort_order] || params["sort_order"])
  end

  @impl true
  def after_focus(%{"data" => tweets} = response) do
    users = get_in(response, ["includes", "users"]) || []
    meta = response["meta"] || %{}

    formatted_tweets =
      Enum.map(tweets, fn tweet ->
        author = Enum.find(users, fn u -> u["id"] == tweet["author_id"] end)

        %{
          id: tweet["id"],
          text: tweet["text"],
          author_id: tweet["author_id"],
          author: format_user(author),
          created_at: tweet["created_at"],
          metrics: tweet["public_metrics"],
          referenced_tweets: tweet["referenced_tweets"] || []
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

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
