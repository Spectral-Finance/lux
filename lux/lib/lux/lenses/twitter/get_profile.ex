defmodule Lux.Lenses.Twitter.GetProfile do
  @moduledoc """
  A lens that fetches a user profile using the Twitter v2 API.
  """
  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Twitter Profile Reader",
    description: "Reads the profile of a Twitter user by username.",
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
            "The Twitter username/handle (without the @ symbol) to fetch the profile for."
        }
      },
      required: ["username"]
    }

  def before_focus(params) do
    # Assign defaults for params so it's handled properly by the API
    params
    |> Map.put("user.fields", "created_at,description,public_metrics,profile_image_url")
  end

  @impl true
  def after_focus(%{"data" => data}) do
    {:ok, data}
  end

  def after_focus(%{"errors" => errors}) do
    {:error, errors}
  end

  def after_focus(other) do
    {:ok, other}
  end
end
