defmodule Lux.Lenses.Twitter.GetUser do
  @moduledoc """
  Lens for fetching Twitter user profiles via API v2.

  Supports lookup by user ID or username.

  ## Examples

      iex> GetUser.focus(%{username: "elikirf"})
      {:ok, %{id: "123", name: "Eli", username: "elikirf", ...}}
  """

  use Lux.Lens,
    name: "Get User",
    description: "Fetches a Twitter user profile by ID or username",
    url: "https://api.twitter.com/2/users",
    method: :get,
    headers: [{"Content-Type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Lux.Integrations.Twitter.add_auth_header/1
    },
    schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string, description: "User ID to fetch"},
        username: %{type: :string, description: "Username to fetch (without @)"}
      }
    }

  alias Lux.Integrations.Twitter.Client

  @default_user_fields "id,name,username,created_at,description,public_metrics,profile_image_url,verified,location,url"

  @impl true
  def before_focus(params) do
    user_id = params[:user_id] || params["user_id"]
    username = params[:username] || params["username"]

    {url, query_params} =
      cond do
        user_id ->
          {"https://api.twitter.com/2/users/#{user_id}",
           %{"user.fields" => @default_user_fields}}

        username ->
          {"https://api.twitter.com/2/users/by/username/#{username}",
           %{"user.fields" => @default_user_fields}}

        true ->
          {"https://api.twitter.com/2/users/me",
           %{"user.fields" => @default_user_fields}}
      end

    %{url: url, params: query_params}
  end

  @impl true
  def after_focus(%{"data" => data}) do
    {:ok, format_user(data)}
  end

  def after_focus(%{"errors" => [%{"detail" => detail} | _]}) do
    {:error, detail}
  end

  def after_focus(other), do: {:error, "Unexpected response: #{inspect(other)}"}

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
