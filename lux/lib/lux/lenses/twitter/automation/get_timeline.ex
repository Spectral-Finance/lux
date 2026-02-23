defmodule Lux.Lenses.Twitter.Automation.GetTimeline do
  @moduledoc """
  A lens for retrieving a user's Twitter timeline.

  Fetches recent tweets from a user's timeline for monitoring and content curation.

  ## Examples

      iex> GetTimeline.focus(%{
      ...>   "user_id" => "123456789",
      ...>   "max_results" => 20
      ...> }, %{})
      {:ok, %{tweets: [...], result_count: 20}}
  """

  use Lux.Lens,
    name: "Get Twitter Timeline",
    description: "Retrieve tweets from a user's timeline for monitoring and curation",
    schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :string,
          description: "Twitter user ID whose timeline to retrieve"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of tweets to return (5-100)",
          minimum: 5,
          maximum: 100
        },
        tweet_fields: %{
          type: :array,
          items: %{type: :string},
          description: "Tweet fields to include"
        },
        exclude: %{
          type: :array,
          items: %{type: :string, enum: ["retweets", "replies"]},
          description: "Tweet types to exclude from results"
        },
        pagination_token: %{
          type: :string,
          description: "Token for paginating results"
        }
      },
      required: ["user_id"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  @default_tweet_fields ["id", "text", "created_at", "public_metrics", "entities"]

  defoverridable focus: 2

  @doc """
  Fetches the timeline for the given user.
  """
  def focus(params, _context) do
    user_id = params["user_id"] || params[:user_id]
    max_results = params["max_results"] || params[:max_results] || 10
    tweet_fields = params["tweet_fields"] || params[:tweet_fields] || @default_tweet_fields
    exclude = params["exclude"] || params[:exclude] || []

    query_params =
      %{
        "max_results" => max_results,
        "tweet.fields" => Enum.join(tweet_fields, ",")
      }
      |> maybe_add_exclude(exclude)
      |> maybe_add_param(params, "pagination_token")

    Logger.info("Fetching timeline for user: #{user_id}")

    case Client.request(:get, "/users/#{user_id}/tweets", %{params: query_params}) do
      {:ok, %{"data" => tweets, "meta" => meta}} ->
        {:ok, %{
          tweets: Enum.map(tweets, &format_tweet/1),
          result_count: meta["result_count"] || length(tweets),
          newest_id: meta["newest_id"],
          oldest_id: meta["oldest_id"],
          next_token: meta["next_token"]
        }}

      {:ok, %{"meta" => %{"result_count" => 0}}} ->
        {:ok, %{tweets: [], result_count: 0}}

      {:error, error} ->
        Logger.error("Failed to get timeline for user #{user_id}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp format_tweet(tweet) do
    %{
      id: tweet["id"],
      text: tweet["text"],
      created_at: tweet["created_at"],
      metrics: tweet["public_metrics"] || %{},
      entities: tweet["entities"] || %{}
    }
  end

  defp maybe_add_exclude(params, []), do: params
  defp maybe_add_exclude(params, exclude) when is_list(exclude),
    do: Map.put(params, "exclude", Enum.join(exclude, ","))
  defp maybe_add_exclude(params, exclude) when is_binary(exclude),
    do: Map.put(params, "exclude", exclude)

  defp maybe_add_param(params, source, key) do
    val = source[key] || source[String.to_atom(key)]
    case val do
      nil -> params
      value -> Map.put(params, key, value)
    end
  end
end
