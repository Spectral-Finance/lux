defmodule Lux.Prisms.Discord.Roles.RemoveRole do
  @moduledoc """
  A prism for removing a role from a Discord server member.

  ## Examples

      iex> RemoveRole.handler(%{
      ...>   guild_id: "111111111111111111",
      ...>   user_id: "222222222222222222",
      ...>   role_id: "333333333333333333"
      ...> }, %{name: "Agent"})
      {:ok, %{removed: true, user_id: "222222222222222222", role_id: "333333333333333333"}}
  """

  use Lux.Prism,
    name: "Remove Discord Role",
    description: "Removes a role from a member in a Discord server",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the server",
          pattern: "^[0-9]{17,20}$"
        },
        user_id: %{
          type: :string,
          description: "The ID of the user to remove the role from",
          pattern: "^[0-9]{17,20}$"
        },
        role_id: %{
          type: :string,
          description: "The ID of the role to remove",
          pattern: "^[0-9]{17,20}$"
        },
        reason: %{
          type: :string,
          description: "Optional audit log reason for the role removal",
          maxLength: 500
        }
      },
      required: ["guild_id", "user_id", "role_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        removed: %{type: :boolean, description: "Whether the role was successfully removed"},
        user_id: %{type: :string, description: "The ID of the user"},
        role_id: %{type: :string, description: "The ID of the removed role"}
      },
      required: ["removed"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, user_id} <- validate_param(params, :user_id),
         {:ok, role_id} <- validate_param(params, :role_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} removing role #{role_id} from user #{user_id} in server #{guild_id}")

      case Client.request(:delete, "/guilds/#{guild_id}/members/#{user_id}/roles/#{role_id}", %{}) do
        {:ok, _} ->
          {:ok, %{removed: true, user_id: user_id, role_id: role_id}}
        {:error, %{"status" => 204}} ->
          {:ok, %{removed: true, user_id: user_id, role_id: role_id}}
        error ->
          Logger.error("Failed to remove role: #{inspect(error)}")
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
