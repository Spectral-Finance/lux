defmodule Lux.Lenses.Twitter.UnfollowUser do
  @moduledoc """
  Lens for unfollowing a Twitter user.

  ## Examples
      Lux.Lenses.Twitter.UnfollowUser.focus(%{
        source_user_id: "123456789",
        target_user_id: "987654321"
      })
  """
  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Unfollow User",
    description: "Unfollow a Twitter user",
    url: "https://api.twitter.com/2/users/:source_user_id/following/:target_user_id",
    method: :delete,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        source_user_id: %{type: :string, description: "The authenticated user's ID"},
        target_user_id: %{type: :string, description: "The user ID to unfollow"}
      },
      required: ["source_user_id", "target_user_id"]
    }

  @impl true
  def before_focus(params) do
    source_user_id = Map.get(params, :source_user_id) || Map.get(params, "source_user_id")
    target_user_id = Map.get(params, :target_user_id) || Map.get(params, "target_user_id")

    url =
      "https://api.twitter.com/2/users/:source_user_id/following/:target_user_id"
      |> String.replace(":source_user_id", source_user_id)
      |> String.replace(":target_user_id", target_user_id)

    {:ok, %{url: url}}
  end

  @impl true
  def after_focus(%{"data" => data}) do
    {:ok,
     %{
       following: data["following"]
     }}
  end

  def after_focus(%{"errors" => errors}), do: {:error, errors}
  def after_focus(%{"title" => title, "detail" => detail}), do: {:error, "#{title}: #{detail}"}
  def after_focus(other), do: {:error, other}
end
