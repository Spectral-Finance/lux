defmodule Lux.Prisms.Discord.Roles.RemoveRole do
  @moduledoc """
  A prism for removing a role from a member in a Discord guild.

  This prism provides an interface for removing a role with:
  - Required parameters (guild_id, user_id, role_id)
  - Success/failure response structure
  """

  use Lux.Prism,
    name: "Remove Discord Role from Member",
    description: "Removes a specific role from a member in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild",
          pattern: "^[0-9]{17,20}$"
        },
        user_id: %{
          type: :string,
          description: "The ID of the member",
          pattern: "^[0-9]{17,20}$"
        },
        role_id: %{
          type: :string,
          description: "The ID of the role to remove",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id", "user_id", "role_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        removed: %{
          type: :boolean,
          description: "Whether the role was successfully removed"
        },
        guild_id: %{type: :string},
        user_id: %{type: :string},
        role_id: %{type: :string}
      },
      required: ["removed"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to remove a role from a member.
  """
  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, user_id} <- validate_param(params, :user_id),
         {:ok, role_id} <- validate_param(params, :role_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} removing role #{role_id} from member #{user_id} in guild #{guild_id}")

      req_opts = Map.take(params, [:plug])

      case Client.request(
             :delete,
             "/guilds/#{guild_id}/members/#{user_id}/roles/#{role_id}",
             req_opts
           ) do
        {:ok, _body} ->
          Logger.info("Successfully removed role #{role_id} from member #{user_id} in guild #{guild_id}")
          {:ok, %{removed: true, guild_id: guild_id, user_id: user_id, role_id: role_id}}

        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to remove role: #{inspect(error)}")
          {:error, error}

        {:error, error} ->
          Logger.error("Failed to remove role: #{inspect(error)}")
          {:error, error}
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
