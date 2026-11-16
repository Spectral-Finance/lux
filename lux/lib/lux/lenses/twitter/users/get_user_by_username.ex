defmodule Lux.Lenses.Twitter.Users.GetUserByUsername do
  @moduledoc """
  A lens for fetching a Twitter/X user profile by username via Twitter API v2 (`/2/users/by/username/:username`).

  ## Examples

      iex> GetUserByUsername.focus(%{"username" => "spectralfi"})
      {:ok, %{
        id: "12345",
        username: "spectralfi",
        name: "Spectral"
      }}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Get Twitter User by Username",
    description: "Retrieves user profile details and public metrics for a Twitter/X username",
    url: "https://api.twitter.com/2/users/by/username/:username",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        username: %{
          type: :string,
          description: "The Twitter/X handle (without leading @) to look up"
        },
        user_fields: %{
          type: :string,
          description: "Optional comma-separated fields (e.g. 'description,public_metrics,verified')"
        }
      },
      required: ["username"]
    }

  @impl true
  def after_focus(%{"data" => %{"id" => id, "username" => username, "name" => name} = data}) do
    {:ok,
     %{
       id: id,
       username: username,
       name: name,
       description: Map.get(data, "description"),
       public_metrics: Map.get(data, "public_metrics", %{})
     }}
  end

  def after_focus(%{"errors" => errors}) do
    {:error, %{"errors" => errors}}
  end

  def after_focus(error) do
    {:error, error}
  end
end
