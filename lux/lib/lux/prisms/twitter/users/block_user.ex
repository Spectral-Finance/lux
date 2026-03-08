defmodule Lux.Prisms.Twitter.Users.BlockUser do
  @moduledoc """
  Prism for blocking/unblocking users via Twitter API v2.
  """

  use Lux.Prism,
    name: "Block User",
    description: "Blocks or unblocks a Twitter user",
    input_schema: %{
      type: :object,
      properties: %{
        target_user_id: %{type: :string, description: "User ID to block/unblock"},
        user_id: %{type: :string, description: "Authenticated user's ID"},
        unblock: %{type: :boolean, description: "If true, unblock", default: false}
      },
      required: ["target_user_id", "user_id"]
    }

  alias Lux.Integrations.Twitter.Client

  def handler(%{"target_user_id" => target, "user_id" => user_id} = params, _context) do
    if params["unblock"] do
      case Client.request(:delete, "/users/#{user_id}/blocking/#{target}", %{auth_type: :oauth1}) do
        {:ok, _} -> {:ok, %{blocked: false, target_user_id: target}}
        {:error, reason} -> {:error, "Failed to unblock: #{inspect(reason)}"}
      end
    else
      case Client.request(:post, "/users/#{user_id}/blocking", %{
             auth_type: :oauth1,
             json: %{"target_user_id" => target}
           }) do
        {:ok, _} -> {:ok, %{blocked: true, target_user_id: target}}
        {:error, reason} -> {:error, "Failed to block: #{inspect(reason)}"}
      end
    end
  end
end
