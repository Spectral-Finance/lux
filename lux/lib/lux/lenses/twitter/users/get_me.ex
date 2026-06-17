defmodule Lux.Lenses.Twitter.Users.GetMe do
  @moduledoc """
  A lens for retrieving the authenticated user's profile from Twitter API v2.

  This is a convenience lens that returns the profile of the user associated
  with the provided Bearer token or OAuth credentials.

  ## Examples

      iex> GetMe.focus(%{})
      {:ok, %{
        id: "123456789",
        name: "My Bot",
        username: "mybot",
        ...
      }}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Get Me",
    description: "Retrieves the authenticated user's profile information",
    url: "https://api.twitter.com/2/users/me",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    params: %{
      "user.fields" => "id,name,username,description,profile_image_url,public_metrics,verified,created_at"
    },
    schema: %{
      type: :object,
      properties: %{
        user_fields: %{
          type: :string,
          description: "Comma-separated list of user fields to include"
        }
      }
    }

  @doc """
  Transforms the Twitter API user response into a simpler format.
  """
  @impl true
  def after_focus(%{"data" => user}) do
    {:ok,
     %{
       id: user["id"],
       name: user["name"],
       username: user["username"],
       description: user["description"],
       profile_image_url: user["profile_image_url"],
       metrics: user["public_metrics"],
       verified: user["verified"] || false,
       created_at: user["created_at"]
     }}
  end

  def after_focus(%{"errors" => errors}) do
    {:error, %{errors: errors}}
  end

  def after_focus(%{"title" => title, "detail" => detail}) do
    {:error, %{title: title, detail: detail}}
  end
end
