defmodule Lux.Lenses.Twitter.Users.GetUser do
  @moduledoc """
  A lens for retrieving Twitter user profile information by username.
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Get Twitter User",
    description: "Retrieves user profile information by username",
    url: "https://api.twitter.com/2/users/by/username/:username",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        username: %{
          type: :string,
          description: "The Twitter username/handle to lookup (without @)"
        }
      },
      required: ["username"]
    }

  @impl true
  def before_focus(%{username: username} = params) do
    clean_username = String.trim_leading(username, "@")
    {:ok, %{params | username: clean_username}}
  end

  @impl true
  def after_focus(%{"data" => user}) do
    {:ok, user}
  end

  def after_focus(other), do: {:ok, other}
end
