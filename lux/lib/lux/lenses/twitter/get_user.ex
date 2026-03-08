defmodule Lux.Lenses.Twitter.GetUser do
  @moduledoc """
  Lens for fetching Twitter user profiles via API v2.

  Supports lookup by user ID or username.

  ## Examples

      iex> GetUser.focus(%{username: "elikirf"})
      {:ok, %{id: "123", name: "Eli", username: "elikirf", ...}}
  """

  alias Lux.Integrations.Twitter.Client

  @default_user_fields "id,name,username,created_at,description,public_metrics,profile_image_url,verified,location,url"

  def focus(params, _opts \\ []) do
    user_id = params[:user_id] || params["user_id"]
    username = params[:username] || params["username"]

    path =
      cond do
        user_id -> "/users/#{user_id}"
        username -> "/users/by/username/#{username}"
        true -> "/users/me"
      end

    query_params = %{"user.fields" => @default_user_fields}

    case Client.request(:get, path, %{params: query_params}) do
      {:ok, %{data: data}} when is_map(data) -> {:ok, format_user(data)}
      {:error, error} -> {:error, error}
    end
  end

  defp format_user(data) do
    metrics = data["public_metrics"] || %{}

    %{
      id: data["id"],
      name: data["name"],
      username: data["username"],
      description: data["description"],
      created_at: data["created_at"],
      verified: data["verified"] || false,
      location: data["location"],
      url: data["url"],
      profile_image_url: data["profile_image_url"],
      metrics: %{
        followers: metrics["followers_count"] || 0,
        following: metrics["following_count"] || 0,
        tweets: metrics["tweet_count"] || 0,
        listed: metrics["listed_count"] || 0
      }
    }
  end
end
