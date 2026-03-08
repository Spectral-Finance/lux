defmodule Lux.Prisms.Twitter.Users.MuteUser do
  @moduledoc """
  Prism for muting/unmuting users via Twitter API v2.
  """

  use Lux.Prism,
    name: "Mute User",
    description: "Mutes or unmutes a Twitter user",
    input_schema: %{
      type: :object,
      properties: %{
        target_user_id: %{type: :string, description: "User ID to mute/unmute"},
        user_id: %{type: :string, description: "Authenticated user's ID"},
        unmute: %{type: :boolean, description: "If true, unmute", default: false}
      },
      required: ["target_user_id", "user_id"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{"target_user_id" => target, "user_id" => user_id} = params, _context) do
    if params["unmute"] do
      case Client.request(:delete, "/users/#{user_id}/muting/#{target}", %{auth_type: :oauth1}) do
        {:ok, _} -> {:ok, %{muted: false, target_user_id: target}}
        {:error, reason} -> {:error, "Failed to unmute: #{inspect(reason)}"}
      end
    else
      case Client.request(:post, "/users/#{user_id}/muting", %{
             auth_type: :oauth1,
             json: %{"target_user_id" => target}
           }) do
        {:ok, _} -> {:ok, %{muted: true, target_user_id: target}}
        {:error, reason} -> {:error, "Failed to mute: #{inspect(reason)}"}
      end
    end
  end
end
