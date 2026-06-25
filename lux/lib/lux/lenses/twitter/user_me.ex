defmodule Lux.Lenses.Twitter.UserMe do
  @moduledoc """
  Lens for fetching the authenticated user's profile from Twitter API v2.

  ## Examples

      iex> Lux.Lenses.Twitter.UserMe.focus()
      {:ok, %{id: "123456", name: "My Account", username: "myaccount"}}
  """

  use Lux.Lens,
    name: "Twitter.UserMe",
    description: "Fetches the authenticated user's profile information from Twitter",
    url: "https://api.twitter.com/2/users/me",
    method: :get,
    auth: %{
      type: :custom,
      auth_function: &Lux.Integrations.Twitter.add_auth_header/1
    },
    schema: %{
      type: :object,
      properties: %{
        "expansions" => %{
          type: :string,
          description: "Comma-separated list of field expansions (e.g. 'pinned_tweet_id')"
        },
        "tweet.fields" => %{
          type: :string,
          description: "Comma-separated list of tweet fields to include in expansions"
        },
        "user.fields" => %{
          type: :string,
          description: "Comma-separated list of user fields to return (default: all)"
        }
      },
      required: []
    }

  @doc """
  Transforms the Twitter API response into a usable format.
  """
  def after_focus(%{"data" => user} = _body) do
    {:ok, %{
      id: Map.get(user, "id"),
      name: Map.get(user, "name"),
      username: Map.get(user, "username"),
      created_at: Map.get(user, "created_at"),
      description: Map.get(user, "description"),
      public_metrics: Map.get(user, "public_metrics"),
      verified: Map.get(user, "verified"),
      profile_image_url: Map.get(user, "profile_image_url"),
      raw_data: user
    }}
  end

  def after_focus(%{"errors" => errors}) do
    {:error, List.first(errors)["message"]}
  end

  def after_focus(body), do: {:ok, body}
end
