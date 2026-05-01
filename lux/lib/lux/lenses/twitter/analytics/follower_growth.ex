defmodule Lux.Lenses.Twitter.Analytics.FollowerGrowth do
  @moduledoc """
  Lens for tracking follower growth and user metrics from the Twitter/X API v2.

  Retrieves user-level metrics including follower count, following count,
  tweet count, and listed count. Supports historical analysis through
  repeated polling for growth tracking.

  ## Examples

      iex> FollowerGrowth.focus(%{user_id: "2244994945"})
      {:ok, %{user_metrics: %{followers: 1000, following: 500, tweets: 2000, ...}}}

      iex> FollowerGrowth.focus(%{username: "TwitterDev"})
      {:ok, %{user_metrics: %{followers: 1000, following: 500, ...}}}
  """

  use Lux.Lens,
    name: "Twitter Follower Growth Tracking",
    description: "Tracks follower count, following count, and user-level metrics for growth analysis",
    url: "https://api.twitter.com/2/users",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :string,
          description: "Twitter user ID to analyze"
        },
        username: %{
          type: :string,
          description: "Twitter username (without @) to analyze"
        }
      },
      required: []
    }

  alias Lux.Integrations.Twitter

  def before_focus(params) do
    user_id = Map.get(params, :user_id)
    username = Map.get(params, :username)

    params
    |> maybe_put_id(user_id, username)
    |> Map.put(:"user.fields", "public_metrics,created_at,verified,profile_image_url")
    |> Map.delete(:user_id)
    |> Map.delete(:username)
  end

  def after_focus(%{"data" => users}) when is_list(users) do
    metrics = Enum.map(users, fn user ->
      public_metrics = Map.get(user, "public_metrics", %{})

      %{
        user_id: user["id"],
        username: user["username"],
        name: Map.get(user, "name", ""),
        followers: Map.get(public_metrics, "followers_count", 0),
        following: Map.get(public_metrics, "following_count", 0),
        tweets: Map.get(public_metrics, "tweet_count", 0),
        listed: Map.get(public_metrics, "listed_count", 0),
        verified: Map.get(user, "verified", false),
        created_at: Map.get(user, "created_at", "")
      }
    end)

    {:ok, %{user_metrics: metrics, count: length(metrics)}}
  end

  def after_focus(%{"data" => user}) when is_map(user) do
    public_metrics = Map.get(user, "public_metrics", %{})

    {:ok, %{
      user_metrics: %{
        user_id: user["id"],
        username: user["username"],
        name: Map.get(user, "name", ""),
        followers: Map.get(public_metrics, "followers_count", 0),
        following: Map.get(public_metrics, "following_count", 0),
        tweets: Map.get(public_metrics, "tweet_count", 0),
        listed: Map.get(public_metrics, "listed_count", 0),
        verified: Map.get(user, "verified", false),
        created_at: Map.get(user, "created_at", "")
      }
    }}
  end

  def after_focus(%{"errors" => errors}) do
    Twitter.parse_error(%{"errors" => errors})
  end

  def after_focus(body), do: {:ok, body}

  defp maybe_put_id(params, nil, username) when is_binary(username) do
    Map.put(params, :usernames, username)
  end

  defp maybe_put_id(params, user_id, _username) when is_binary(user_id) do
    Map.put(params, :ids, user_id)
  end

  defp maybe_put_id(params, _, _), do: params
end
