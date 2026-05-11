defmodule Lux.Prisms.Discord.Role.AssignRole do
  use Lux.Prism,
    name: "Assign Discord Role",
    description: "Assigns a role to a guild member",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Guild ID", pattern: "^[0-9]{17,20}$"},
        user_id: %{type: :string, description: "User ID to assign role to", pattern: "^[0-9]{17,20}$"},
        role_id: %{type: :string, description: "Role ID to assign", pattern: "^[0-9]{17,20}$"}
      },
      required: ["guild_id", "user_id", "role_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{assigned: %{type: :boolean}},
      required: ["assigned"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, _agent) do
    case Client.request(:put, "/guilds/#{params[:guild_id]}/members/#{params[:user_id]}/roles/#{params[:role_id]}", %{}) do
      {:ok, _} -> {:ok, %{assigned: true}}
      {:error, error} -> {:error, error}
    end
  end
end
