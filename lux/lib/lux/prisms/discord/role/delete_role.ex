defmodule Lux.Prisms.Discord.Role.DeleteRole do
  @moduledoc """
  A prism for deleting Discord roles.
  """

  use Lux.Prism,
    name: "Delete Discord Role",
    description: "Deletes a role from a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Guild ID", pattern: "^[0-9]{17,20}$"},
        role_id: %{type: :string, description: "Role ID to delete", pattern: "^[0-9]{17,20}$"}
      },
      required: ["guild_id", "role_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{type: :boolean},
        guild_id: %{type: :string},
        role_id: %{type: :string}
      },
      required: ["deleted"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, role_id} <- validate_param(params, :role_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} deleting role #{role_id} from guild #{guild_id}")

      case Client.request(:delete, "/guilds/#{guild_id}/roles/#{role_id}") do
        {:ok, _} ->
          Logger.info("Successfully deleted role #{role_id} from guild #{guild_id}")
          {:ok, %{deleted: true, guild_id: guild_id, role_id: role_id}}

        error ->
          Logger.error(
            "Failed to delete role #{role_id} from guild #{guild_id}: #{inspect(error)}"
          )

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
