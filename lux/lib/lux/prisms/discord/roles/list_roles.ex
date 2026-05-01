defmodule Lux.Prisms.Discord.Roles.ListRoles do
  @moduledoc """
  A prism for listing all roles in a Discord server with hierarchy information.

  ## Examples

      iex> ListRoles.handler(%{
      ...>   guild_id: "111111111111111111"
      ...> }, %{name: "Agent"})
      {:ok, %{
        guild_id: "111111111111111111",
        roles: [%{id: "333", name: "Admin", position: 10, permissions: 8}]
      }}
  """

  use Lux.Prism,
    name: "List Discord Server Roles",
    description: "Lists all roles in a Discord server with hierarchy and permission info",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the server",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "The server ID"},
        roles: %{type: :array, description: "List of roles with hierarchy info"}
      },
      required: ["guild_id", "roles"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} listing roles in server #{guild_id}")

      case Client.request(:get, "/guilds/#{guild_id}/roles", %{}) do
        {:ok, roles} when is_list(roles) ->
          role_summaries = roles
            |> Enum.sort_by(& &1["position"], :desc)
            |> Enum.map(fn role ->
              %{
                id: role["id"],
                name: role["name"],
                position: role["position"],
                permissions: role["permissions"],
                color: role["color"],
                hoist: role["hoist"],
                mentionable: role["mentionable"],
                managed: role["managed"]
              }
            end)
          Logger.info("Retrieved #{length(role_summaries)} roles from server #{guild_id}")
          {:ok, %{guild_id: guild_id, roles: role_summaries}}
        error ->
          Logger.error("Failed to list roles: #{inspect(error)}")
          error
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
