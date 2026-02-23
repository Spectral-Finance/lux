defmodule Lux.Lenses.Twitter.Analytics.GetUserMetrics do
  @moduledoc """
  A lens for retrieving user-level metrics for follower growth tracking.

  Fetches public metrics for a Twitter user including follower count,
  following count, tweet count, and listed count.

  ## Authentication

  Uses OAuth 2.0 Bearer Token.

  ## Examples

      iex> GetUserMetrics.focus(%{user_id: "123456789"})
      {:ok, %{
        user_id: "123456789",
        username: "elonmusk",
        name: "Elon Musk",
        metrics: %{
          followers_count: 180_000_000,
          following_count: 500,
          tweet_count: 25_000,
          listed_count: 120_000
        }
      }}

      iex> GetUserMetrics.focus(%{username: "elonmusk"})
      {:ok, %{user_id: "...", username: "elonmusk", ...}}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Get Twitter User Metrics",
    description: "Retrieves follower count, following count, tweet count, and other public metrics for a Twitter user",
    url: "https://api.twitter.com/2/users/:user_id",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :string,
          description: "The Twitter user ID"
        },
        username: %{
          type: :string,
          description: "The Twitter username (without @). Used as fallback if user_id not provided."
        },
        user_fields: %{
          type: :string,
          description: "Additional user fields to include",
          default: "public_metrics,created_at,description,verified"
        }
      }
    }

  @impl true
  def before_focus(params) do
    user_id = params[:user_id] || params["user_id"]
    user_fields = params[:user_fields] || params["user_fields"] || "public_metrics,created_at,verified"
    {:ok, %{user_id: user_id, "user.fields" => user_fields}}
  end

  @impl true
  def after_focus(%{"data" => data}) do
    metrics = data["public_metrics"] || %{}

    {:ok, %{
      user_id: data["id"],
      username: data["username"],
      name: data["name"],
      verified: data["verified"] || false,
      created_at: data["created_at"],
      description: data["description"],
      metrics: %{
        followers_count: metrics["followers_count"] || 0,
        following_count: metrics["following_count"] || 0,
        tweet_count: metrics["tweet_count"] || 0,
        listed_count: metrics["listed_count"] || 0
      }
    }}
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
end
