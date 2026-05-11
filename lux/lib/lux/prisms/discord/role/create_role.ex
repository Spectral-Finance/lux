defmodule Lux.Prisms.Discord.Role.CreateRole do
  use Lux.Prism,
    name: "Create Discord Role",
    description: "Creates a new role in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "The ID of the guild", pattern: "^[0-9]{17,20}$"},
        name: %{type: :string, description: "Role name", minLength: 1, maxLength: 100},
        permissions: %{type: :string, description: "Permission bitwise value (optional)"},
        color: %{type: :integer, description: "Role color as integer (optional)"},
        hoist: %{type: :boolean, description: "Show role separately in sidebar (optional)"},
        mentionable: %{type: :boolean, description: "Allow anyone to mention this role (optional)"}
      },
      required: ["guild_id", "name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{type: :boolean},
        role_id: %{type: :string},
        name: %{type: :string}
      },
      required: ["created"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    guild_id = params[:guild_id]
    name = params[:name]
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} creating role '#{name}' in guild #{guild_id}")

    body = %{name: name}
    body = if params[:permissions], do: Map.put(body, :permissions, params[:permissions]), else: body
    body = if params[:color], do: Map.put(body, :color, params[:color]), else: body
    body = if params[:hoist], do: Map.put(body, :hoist, params[:hoist]), else: body
    body = if params[:mentionable], do: Map.put(body, :mentionable, params[:mentionable]), else: body

    case Client.request(:post, "/guilds/#{guild_id}/roles", %{json: body}) do
      {:ok, %{"id" => role_id, "name" => role_name}} ->
        {:ok, %{created: true, role_id: role_id, name: role_name}}
      {:error, error} ->
        Logger.error("Failed to create role: #{inspect(error)}")
        {:error, error}
    end
  end
end
