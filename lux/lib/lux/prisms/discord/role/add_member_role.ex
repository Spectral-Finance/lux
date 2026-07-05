defmodule Lux.Prisms.Discord.Role.AddMemberRole do
  use Lux.Prism,
    name: "Add Discord Member Role",
    description: "Adds a role to a guild member",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string},
        user_id: %{type: :string},
        role_id: %{type: :string}
      },
      required: ["guild_id", "user_id", "role_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        added: %{type: :boolean}
      },
      required: ["added"]
    }

  alias Lux.Integrations.Discord.Client

  def handler(params, _agent) do
    guild_id = params[:guild_id] || params["guild_id"]
    user_id = params[:user_id] || params["user_id"]
    role_id = params[:role_id] || params["role_id"]

    case Client.request(:put, "/guilds/#{guild_id}/members/#{user_id}/roles/#{role_id}") do
      {:ok, _} -> {:ok, %{added: true}}
      {:error, error} -> {:error, error}
    end
  end
end\n