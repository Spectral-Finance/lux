defmodule Lux.Lenses.Twitter.Users.GetUser do
  @moduledoc """
  A lens for retrieving user profile information from Twitter API v2.

  Returns user data including profile details, metrics, and verification status.

  ## Examples

      iex> GetUser.focus(%{user_id: "123456789"})
      {:ok, %{
        id: "123456789",
        name: "Elixir Lang",
        username: "elixirlang",
        ...
      }}

      iex> GetUser.focus(%{username: "elixirlang"})
      {:ok, %{...}}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Get User",
    description: "Retrieves Twitter user profile information",
    url: "https://api.twitter.com/2/users/:user_id",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    params: %{
      "user.fields" => "id,name,username,description,profile_image_url,public_metrics,verified,created_at"
    },
    schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :string,
          description: "The ID of the user to retrieve"
        },
        user_fields: %{
          type: :string,
          description: "Comma-separated list of user fields to include"
        }
      },
      required: ["user_id"]
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
