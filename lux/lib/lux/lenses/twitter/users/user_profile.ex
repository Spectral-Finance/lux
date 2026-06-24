defmodule Lux.Lenses.Twitter.Users.UserProfile do
  @moduledoc """
  A lens for fetching a Twitter/X user's profile by their user ID.

  ## Examples

      iex> UserProfile.focus(%{user_id: "123456789"})
      {:ok, %{data: %{id: "123456789", name: "Lux Agent", username: "LuxAgent"}}}
  """

  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "User Profile",
    description: "Fetches a Twitter/X user's profile by ID",
    url: "#{Twitter.base_url()}/users/:user_id",
    method: :get,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        user_id: %{
          type: :string,
          description: "The ID of the user to fetch"
        },
        expansions: %{
          type: :array,
          description: "Expansion fields (pinned_tweet_id, etc.)",
          items: %{type: :string}
        },
        user_fields: %{
          type: :array,
          description: "Additional user fields (description, profile_image_url, public_metrics, etc.)",
          items: %{type: :string}
        }
      },
      required: ["user_id"]
    }

  def after_focus(%{"data" => data} = body) do
    result = %{data: data}

    result =
      case Map.get(body, "includes") do
        nil -> result
        includes -> Map.put(result, :includes, includes)
      end

    {:ok, result}
  end

  def after_focus(%{"errors" => errors}) do
    {:error, errors}
  end

  def after_focus(body) do
    {:error, %{error: "Unexpected response", raw: body}}
  end
end
