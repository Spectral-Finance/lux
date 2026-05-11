defmodule Lux.Prisms.Discord.Role.RemoveRole do
  use Lux.Prism,
    name: "Remove Discord Role",
    description: "Removes a role from a guild member",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Guild ID", pattern: "^[0-9]{17,20}$"},
        user_id: %{type: :string, description: "User ID", pattern: "^[0-9]{17,20}$"},
        role_id: %{type: :string, description: "Role ID to remove", pattern: "^[0-9]{17,20}$"}
      },
      required: ["guild_id", "user_id", "role_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{removed: %{type: :boolean}},
      required: ["removed"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, _agent) do
    case Client.request(:delete, "/guilds/#{params[:guild_id]}/members/#{params[:user_id]}/roles/#{params[:role_id]}", %{}) do
      {:ok, _} -> {:ok, %{removed: true}}
      {:error, error} -> {:error, error}
    end
  end
end
