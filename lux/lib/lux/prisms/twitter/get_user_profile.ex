defmodule Lux.Prisms.Twitter.GetUserProfile do
  @moduledoc """
  A prism for fetching a user's profile via the Twitter API v2.
  """
  use Lux.Prism,
    name: "Get User Profile",
    description: "Fetches user profile information such as description, public metrics, etc.",
    input_schema: %{
      type: :object,
      properties: %{
        username: %{type: :string, description: "The Twitter username to look up"}
      },
      required: ["username"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(input, _ctx) do
    username = Map.get(input, "username") || Map.get(input, :username)
    Client.get_user_profile(username)
  end
end
