defmodule Lux.Lenses.Twitter.Users.GetUserByUsername do
  @moduledoc """
  A lens for retrieving a user by username from the Twitter API v2.

  Same as GetUser but looks up by Twitter handle/username instead of numeric ID.
  Useful when you have a username (@handle) but not the user's ID.

  ## Authentication

  Uses OAuth 2.0 Bearer Token (app-only auth).

  ## Rate Limits

  300 requests per 15 minutes (app-level).

  ## Examples

      iex> GetUserByUsername.focus(%{
      ...>   username: "TwitterDev"
      ...> })
      {:ok, %{
        id: "2244994945",
        name: "Twitter Dev",
        username: "TwitterDev"
      }}

      iex> GetUserByUsername.focus(%{
      ...>   username: "elixirlang",
      ...>   user_fields: "public_metrics,created_at,description"
      ...> })
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Get User By Username",
    description: "Retrieves a user by Twitter username/handle from the Twitter API v2",
    url: "https://api.twitter.com/2/users/by/username/:username",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        username: %{
          type: :string,
          description:
            "The Twitter username (without @ symbol) of the user to retrieve",
          pattern: "^[A-Za-z0-9_]{1,15}$"
        },
        user_fields: %{
          type: :string,
          description:
            "Comma-separated list of user fields to include. Available: created_at, description, entities, id, location, most_recent_tweet_id, name, pinned_tweet_id, profile_image_url, protected, public_metrics, url, username, verified, verified_type, withheld",
          default: "id,name,username,description"
        },
        expansions: %{
          type: :string,
          description: "Expansions to include (e.g. pinned_tweet_id)"
        }
      },
      required: ["username"]
    }

  @doc """
  Transforms the Twitter API user response into a simplified format.

  ## Examples

      iex> after_focus(%{
      ...>   "data" => %{
      ...>     "id" => "2244994945",
      ...>     "name" => "Twitter Dev",
      ...>     "username" => "TwitterDev"
      ...>   }
      ...> })
      {:ok, %{
        id: "2244994945",
        name: "Twitter Dev",
        username: "TwitterDev"
      }}
  """
  @impl true
  def after_focus(%{"data" => user}) do
    {:ok, transform_user(user)}
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

  defp transform_user(data) do
    %{
      id: data["id"],
      name: data["name"],
      username: data["username"]
    }
    |> maybe_add(:description, data["description"])
    |> maybe_add(:location, data["location"])
    |> maybe_add(:url, data["url"])
    |> maybe_add(:profile_image_url, data["profile_image_url"])
    |> maybe_add(:protected, data["protected"])
    |> maybe_add(:verified, data["verified"])
    |> maybe_add(:verified_type, data["verified_type"])
    |> maybe_add(:created_at, data["created_at"])
    |> maybe_add(:pinned_tweet_id, data["pinned_tweet_id"])
    |> maybe_add(:public_metrics, transform_user_metrics(data["public_metrics"]))
  end

  defp transform_user_metrics(nil), do: nil

  defp transform_user_metrics(metrics) do
    %{
      followers_count: metrics["followers_count"],
      following_count: metrics["following_count"],
      tweet_count: metrics["tweet_count"],
      listed_count: metrics["listed_count"],
      like_count: metrics["like_count"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp maybe_add(map, _key, nil), do: map
  defp maybe_add(map, key, value), do: Map.put(map, key, value)
end
