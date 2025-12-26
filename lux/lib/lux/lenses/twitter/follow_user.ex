defmodule Lux.Lenses.Twitter.FollowUser do
  @moduledoc """
  Lens for following a Twitter user.

  ## Examples
      Lux.Lenses.Twitter.FollowUser.focus(%{
        user_id: "123456789",
        target_user_id: "987654321"
      })
  """
  alias Lux.Integrations.Twitter

  use Lux.Lens,
    name: "Follow User",
    description: "Follow a Twitter user",
    url: "https://api.twitter.com/2/users/:user_id/following",
    method: :post,
    headers: Twitter.headers(),
    auth: Twitter.auth(),
    schema: %{
      type: :object,
      properties: %{
        user_id: %{type: :string, description: "The authenticated user's ID"},
        target_user_id: %{type: :string, description: "The user ID to follow"}
      },
      required: ["user_id", "target_user_id"]
    }

  @impl true
  def before_focus(params) do
    user_id = Map.get(params, :user_id) || Map.get(params, "user_id")
    target_user_id = Map.get(params, :target_user_id) || Map.get(params, "target_user_id")

    url = String.replace("https://api.twitter.com/2/users/:user_id/following", ":user_id", user_id)

    {:ok, %{
      url: url,
      json: %{target_user_id: target_user_id}
    }}
  end

  @impl true
  def after_focus(%{"data" => data}) do
    {:ok,
     %{
       following: data["following"],
       pending_follow: data["pending_follow"]
     }}
  end

  def after_focus(%{"errors" => errors}), do: {:error, errors}
  def after_focus(%{"title" => title, "detail" => detail}), do: {:error, "#{title}: #{detail}"}
  def after_focus(other), do: {:error, other}
end
