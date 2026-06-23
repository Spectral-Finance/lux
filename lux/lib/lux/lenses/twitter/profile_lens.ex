defmodule Lux.Lenses.Twitter.ProfileLens do
  @moduledoc """
  Lens to fetch the authenticated user's Twitter profile.
  """
  use Lux.Lens,
    name: "Twitter Profile",
    description: "Fetches the authenticated user's profile from Twitter",
    url: "https://api.twitter.com/2/users/me",
    method: :get,
    auth: %{type: :custom, auth_function: &__MODULE__.auth/1},
    params: %{"user.fields" => "description,profile_image_url"},
    schema: %{
      type: :object,
      properties: %{
        token: %{type: :string, description: "OAuth 2.0 Bearer token"}
      },
      required: ["token"]
    }

  @doc false
  def auth(lens) do
    token = lens.params[:token] || lens.params["token"]
    %{lens | headers: lens.headers ++ [{"Authorization", "Bearer #{token}"}]}
  end

  @impl true
  def before_focus(params) do
    # Remove token from query params to avoid passing it to Twitter API as a query param
    Map.drop(params, [:token, "token"])
  end

  @impl true
  def after_focus(%{"data" => data}) do
    {:ok, %Lux.Lens.Twitter.Profile{
      id: data["id"],
      name: data["name"],
      username: data["username"],
      description: data["description"],
      profile_image_url: data["profile_image_url"]
    }}
  end

  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  def after_focus(%{"errors" => errors}) do
    {:error, List.first(errors)["detail"]}
  end
  
  def after_focus(response) do
    {:error, "Unknown error format: #{inspect(response)}"}
  end
end
