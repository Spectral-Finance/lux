defmodule Lux.Prisms.Discord.Role.CreateRole do
  use Lux.Prism,
    name: "Create Discord Role",
    description: "Creates a new role in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "The ID of the guild"},
        name: %{type: :string, description: "The name of the role"},
        color: %{type: :integer, description: "RGB color value"},
        permissions: %{type: :string, description: "Bitwise value of permissions"}
      },
      required: ["guild_id", "name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{type: :boolean},
        role_id: %{type: :string}
      },
      required: ["created", "role_id"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    guild_id = params[:guild_id] || params["guild_id"]
    name = params[:name] || params["name"]

    json = %{name: name}
    json = if Map.has_key?(params, :color) or Map.has_key?(params, "color"), do: Map.put(json, :color, params[:color] || params["color"]), else: json
    json = if Map.has_key?(params, :permissions) or Map.has_key?(params, "permissions"), do: Map.put(json, :permissions, params[:permissions] || params["permissions"]), else: json

    case Client.request(:post, "/guilds/#{guild_id}/roles", %{json: json}) do
      {:ok, %{"id" => role_id}} -> {:ok, %{created: true, role_id: role_id}}
      {:error, error} -> {:error, error}
    end
  end
end\n