defmodule Lux.Lenses.Twitter.TwitterTimelineLens do
  @moduledoc """
  Lens for fetching and analyzing Twitter/X timeline data via the Twitter API v2.

  Retrieves user timelines, mentions, and tweet data for analysis.
  Supports filtering by tweet ID, user ID, and date ranges.

  ## Example

      iex> Lux.Lenses.Twitter.TwitterTimelineLens.focus(%{user_id: "12345", max_results: 10})
      {:ok, %{tweets: [...], user_id: "12345", total_count: 10}}
  """

  use Lux.Lens,
    name: "Twitter Timeline",
    description: "Fetches and analyzes Twitter/X timeline data including tweets, mentions, and user activity",
    url: "https://api.twitter.com/2/users/:id/tweets",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :api_key,
      key: &System.get_env("TWITTER_BEARER_TOKEN")
    },
    schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :string,
          description: "Twitter user ID to fetch timeline for"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of tweets to return (5-100)",
          default: 10
        },
        tweet_fields: %{
          type: :string,
          description: "Comma-separated list of tweet fields to include",
          default: "created_at,author_id,public_metrics,conversation_id,lang,source,possibly_sensitive,context_annotations"
        },
        exclude: %{
          type: :string,
          description: "Comma-separated list of tweet types to exclude (retweets,replies)",
          default: "retweets"
        },
        since_id: %{
          type: :string,
          description: "Returns results with a Tweet ID greater than the specified ID"
        },
        until_id: %{
          type: :string,
          description: "Returns results with a Tweet ID less than the specified ID"
        },
        start_time: %{
          type: :string,
          description: "YYYY-MM-DDTHH:mm:ssZ format, oldest UTC timestamp from which to return tweets"
        },
        end_time: %{
          type: :string,
          description: "YYYY-MM-DDTHH:mm:ssZ format, newest UTC timestamp from which to return tweets"
        }
      },
      required: ["user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string},
        total_count: %{type: :integer},
        next_token: %{type: :string},
        tweets: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              id: %{type: :string},
              text: %{type: :string},
              created_at: %{type: :string},
              author_id: %{type: :string},
              public_metrics: %{type: :object},
              conversation_id: %{type: :string},
              lang: %{type: :string},
              source: %{type: :string},
              possibly_sensitive: %{type: :boolean},
              context_annotations: %{type: :array}
            }
          }
        }
      }
    }

  @default_fields "created_at,author_id,public_metrics,conversation_id,lang,source,possibly_sensitive,context_annotations"
  @default_exclude "retweets"

  @doc """
  Fetches timeline data for a specific Twitter user.
  """
  def focus(params) do
    user_id = Map.get(params, :user_id, params["user_id"])
    max_results = Map.get(params, :max_results, params["max_results"] || 10)
    tweet_fields = Map.get(params, :tweet_fields, params["tweet_fields"] || @default_fields)
    exclude = Map.get(params, :exclude, params["exclude"] || @default_exclude)
    since_id = Map.get(params, :since_id, params["since_id"])
    until_id = Map.get(params, :until_id, params["until_id"])
    start_time = Map.get(params, :start_time, params["start_time"])
    end_time = Map.get(params, :end_time, params["end_time"])

    query_params = %{
      "max_results" => max_results,
      "tweet.fields" => tweet_fields,
      "exclude" => exclude
    }
    |> add_optional_param("since_id", since_id)
    |> add_optional_param("until_id", until_id)
    |> add_optional_param("start_time", start_time)
    |> add_optional_param("end_time", end_time)

    with {:ok, response} <- make_request(user_id, query_params: query_params),
         {:ok, data} <- parse_response(response, user_id) do
      {:ok, data}
    end
  end

  defp add_optional_param(params, _key, nil), do: params
  defp add_optional_param(params, key, value), do: Map.put(params, key, value)

  defp make_request(user_id, opts) do
    base_url = Keyword.get(opts, :base_url, @url)
    query_params = Keyword.get(opts, :query_params, %{})
    url = String.replace(base_url, ":id", user_id)

    case Req.get(url, params: query_params, headers: get_headers()) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, "API error #{status}: #{inspect(body)}"}

      {:error, %{reason: reason}} ->
        {:error, "HTTP error: #{inspect(reason)}"}
    end
  end

  defp get_headers do
    [{"Content-Type", "application/json"}]
  end

  defp parse_response(body, user_id) do
    tweets = Map.get(body, "data", [])
    |> Enum.map(&parse_tweet/1)

    next_token = Map.get(body, "meta", %{}) |> Map.get("next_token")
    total_count = Map.get(body, "meta", %{}) |> Map.get("result_count", length(tweets))

    data = %{
      user_id: user_id,
      tweets: tweets,
      total_count: total_count,
      next_token: next_token
    }

    {:ok, data}
  end

  defp parse_tweet(tweet) do
    %{
      id: tweet["id"],
      text: tweet["text"],
      created_at: tweet["created_at"],
      author_id: tweet["author_id"],
      public_metrics: tweet["public_metrics"] || %{},
      conversation_id: tweet["conversation_id"],
      lang: tweet["lang"],
      source: tweet["source"],
      possibly_sensitive: tweet["possibly_sensitive"] || false,
      context_annotations: tweet["context_annotations"] || []
    }
  end
end
