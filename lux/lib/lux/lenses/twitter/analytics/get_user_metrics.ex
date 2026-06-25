defmodule Lux.Lenses.Twitter.Analytics.GetUserMetrics do
  @moduledoc """
  A lens for fetching Twitter/X user-level analytics.

  Retrieves follower count, following count, tweet count, and
  optionally recent follower growth trend via Timeline API.
  Provides the foundation for follower growth tracking and
  audience analytics dashboards.

  ## Examples

      iex> GetUserMetrics.focus(%{
      ...>   username: "elonmusk",
      ...>   bearer_token: "AAAA..."
      ...> })
      {:ok, %{
        user_id: "44196397",
        username: "elonmusk",
        name: "Elon Musk",
        followers_count: 170_000_000,
        following_count: 700,
        tweet_count: 40_000,
        listed_count: 140_000,
        verified: true
      }}
  """

  require Logger

  @base_url "https://api.twitter.com/2"

  use Lux.Lens,
    name: "Get Twitter User Metrics",
    description: "Fetches user profile metrics including follower count, following, and tweet history",
    url: @base_url,
    method: :get,
    headers: [{"Accept", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        username: %{type: :string, description: "Twitter @username (without @)"},
        user_id:  %{type: :string, description: "Twitter user ID (alternative to username)"},
        bearer_token: %{type: :string, description: "Twitter API v2 Bearer token"}
      },
      required: ["bearer_token"]
    }

  @user_fields "public_metrics,created_at,description,entities,location,pinned_tweet_id,profile_image_url,protected,url,verified"

  @impl true
  def focus(%{bearer_token: token} = params) do
    {url, log_id} = cond do
      Map.has_key?(params, :user_id) ->
        {"#{@base_url}/users/#{params.user_id}", params.user_id}
      Map.has_key?(params, :username) ->
        {"#{@base_url}/users/by/username/#{params.username}", params.username}
      true ->
        {"#{@base_url}/users/me", "me"}
    end

    headers = [{"Authorization", "Bearer #{token}"}, {"Accept", "application/json"}]
    query   = %{"user.fields" => @user_fields}

    case Req.get(url, params: query, headers: headers, receive_timeout: 15_000) do
      {:ok, %{status: 200, body: %{"data" => user}}} ->
        metrics = user["public_metrics"] || %{}
        result = %{
          user_id:          user["id"],
          username:         user["username"],
          name:             user["name"],
          description:      user["description"],
          location:         user["location"],
          created_at:       user["created_at"],
          verified:         user["verified"] || false,
          protected:        user["protected"] || false,
          profile_image_url: user["profile_image_url"],
          followers_count:  metrics["followers_count"] || 0,
          following_count:  metrics["following_count"] || 0,
          tweet_count:      metrics["tweet_count"] || 0,
          listed_count:     metrics["listed_count"] || 0
        }
        Logger.info("Fetched metrics for @#{result.username}: #{result.followers_count} followers")
        {:ok, result}

      {:ok, %{status: 401}} -> {:error, :invalid_bearer_token}
      {:ok, %{status: 403}} -> {:error, :insufficient_permissions}
      {:ok, %{status: 404}} -> {:error, {:user_not_found, log_id}}
      {:ok, %{status: 429}} -> {:error, :rate_limited}
      {:ok, %{status: s, body: b}} -> {:error, {s, b}}
      {:error, reason} -> {:error, reason}
    end
  end
end
