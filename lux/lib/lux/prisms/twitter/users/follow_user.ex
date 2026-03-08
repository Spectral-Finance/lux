defmodule Lux.Prisms.Twitter.Users.FollowUser do
  @moduledoc """
  Prism for following/unfollowing users via Twitter API v2.
  """

  use Lux.Prism,
    name: "Follow User",
    description: "Follows or unfollows a Twitter user",
    input_schema: %{
      type: :object,
      properties: %{
        target_user_id: %{type: :string, description: "User ID to follow/unfollow"},
        user_id: %{type: :string, description: "Authenticated user's ID"},
        unfollow: %{type: :boolean, description: "If true, unfollow", default: false}
      },
      required: ["target_user_id", "user_id"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{"target_user_id" => target, "user_id" => user_id} = params, _context) do
    if params["unfollow"] do
      case Client.request(:delete, "/users/#{user_id}/following/#{target}", %{auth_type: :oauth1}) do
        {:ok, _} -> {:ok, %{following: false, target_user_id: target}}
        {:error, reason} -> {:error, "Failed to unfollow: #{inspect(reason)}"}
      end
    else
      case Client.request(:post, "/users/#{user_id}/following", %{
             auth_type: :oauth1,
             json: %{"target_user_id" => target}
           }) do
        {:ok, _} -> {:ok, %{following: true, target_user_id: target}}
        {:error, reason} -> {:error, "Failed to follow: #{inspect(reason)}"}
      end
    end
  end
end
