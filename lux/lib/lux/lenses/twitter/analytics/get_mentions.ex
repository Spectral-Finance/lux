defmodule Lux.Lenses.Twitter.Analytics.GetMentions do
  @moduledoc """
  A lens for retrieving mentions of a Twitter user for sentiment analysis.

  Fetches recent tweets that mention a specific user, including their
  public metrics for engagement analysis.

  ## Authentication

  Uses OAuth 2.0 Bearer Token.

  ## Rate Limits

  180 requests per 15 minutes (app-level).

  ## Examples

      iex> GetMentions.focus(%{user_id: "123456789"})
      {:ok, %{
        user_id: "123456789",
        mentions: [
          %{id: "111", text: "Great work @user!", author_id: "222", metrics: %{like_count: 5}},
          %{id: "333", text: "I disagree with @user", author_id: "444", metrics: %{like_count: 1}}
        ],
        count: 2
      }}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Get Twitter Mentions",
    description: "Retrieves recent tweets that mention a user, for sentiment and engagement analysis",
    url: "https://api.twitter.com/2/users/:user_id/mentions",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :string,
          description: "The Twitter user ID to get mentions for"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of results (5-100, default 10)",
          minimum: 5,
          maximum: 100,
          default: 10
        },
        tweet_fields: %{
          type: :string,
          description: "Tweet fields to include",
          default: "public_metrics,created_at,author_id,text"
        },
        start_time: %{
          type: :string,
          description: "ISO 8601 datetime for earliest mentions (e.g. 2024-01-01T00:00:00Z)"
        }
      },
      required: ["user_id"]
    }

  @impl true
  def before_focus(params) do
    user_id = params[:user_id] || params["user_id"]
    max_results = params[:max_results] || params["max_results"] || 10
    tweet_fields = params[:tweet_fields] || params["tweet_fields"] || "public_metrics,created_at,author_id"

    query = %{
      user_id: user_id,
      max_results: max_results,
      "tweet.fields" => tweet_fields
    }

    query =
      case params[:start_time] || params["start_time"] do
        nil -> query
        t -> Map.put(query, :start_time, t)
      end

    {:ok, query}
  end

  @impl true
  def after_focus(%{"data" => mentions, "meta" => meta}) when is_list(mentions) do
    transformed = Enum.map(mentions, &transform_mention/1)
    {:ok, %{
      mentions: transformed,
      count: length(transformed),
      result_count: meta["result_count"] || length(transformed),
      newest_id: meta["newest_id"],
      oldest_id: meta["oldest_id"]
    }}
  end

  def after_focus(%{"data" => mentions}) when is_list(mentions) do
    transformed = Enum.map(mentions, &transform_mention/1)
    {:ok, %{mentions: transformed, count: length(transformed)}}
  end

  def after_focus(%{"meta" => %{"result_count" => 0}}) do
    {:ok, %{mentions: [], count: 0}}
  end

  def after_focus(%{"errors" => [%{"title" => title, "detail" => detail} | _]}) do
    {:error, %{title: title, detail: detail}}
  end

  def after_focus(%{"title" => title, "detail" => detail}) do
    {:error, %{title: title, detail: detail}}
  end

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end

  defp transform_mention(data) do
    metrics = data["public_metrics"] || %{}
    %{
      id: data["id"],
      text: data["text"],
      author_id: data["author_id"],
      created_at: data["created_at"],
      metrics: %{
        like_count: metrics["like_count"] || 0,
        retweet_count: metrics["retweet_count"] || 0,
        reply_count: metrics["reply_count"] || 0
      }
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
