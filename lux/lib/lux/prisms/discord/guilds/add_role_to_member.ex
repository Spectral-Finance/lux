defmodule Lux.Prisms.Discord.Guilds.AddRoleToMember do
  @moduledoc """
  A prism for assigning roles to members in a Discord guild.

  This prism provides a simple interface for adding roles to guild members with:
  - Required parameters (guild_id, user_id, role_id)
  - Direct Discord API error propagation
  - Simple success/failure response structure

  ## Examples
      iex> AddRoleToMember.handler(%{
      ...>   guild_id: "123456789",
      ...>   user_id: "987654321",
      ...>   role_id: "111222333"
      ...> }, %{name: "Agent"})
      {:ok, %{
        assigned: true,
        role_id: "111222333",
        user_id: "987654321",
        guild_id: "123456789"
      }}
  """

  use Lux.Prism,
    name: "Add Role to Discord Member",
    description: "Assigns a role to a member in a Discord guild",
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
          description: "The ID of the user to assign the role to",
          pattern: "^[0-9]{17,20}$"
        },
        role_id: %{
          type: :string,
          description: "The ID of the role to assign",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: [:guild_id, :user_id, :role_id]
    },
    output_schema: %{
      type: :object,
      properties: %{
        assigned: %{
          type: :boolean,
          description: "Whether the role was successfully assigned"
        },
        role_id: %{
          type: :string,
          description: "The ID of the assigned role"
        },
        user_id: %{
          type: :string,
          description: "The ID of the user who received the role"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the guild where the role was assigned"
        }
      },
      required: [:assigned]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to assign a role to a member in a Discord guild.

  Returns {:ok, %{assigned: true, role_id: role_id, user_id: user_id, guild_id: guild_id}} on success.
  Returns {:error, {status, message}} on failure.
  """
  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, user_id} <- validate_param(params, :user_id),
         {:ok, role_id} <- validate_param(params, :role_id) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} assigning role #{role_id} to user #{user_id} in guild #{guild_id}")

      case Client.request(:put, "/guilds/#{guild_id}/members/#{user_id}/roles/#{role_id}") do
        {:ok, _} ->
          Logger.info("Successfully assigned role #{role_id} to user #{user_id} in guild #{guild_id}")
          {:ok, %{assigned: true, role_id: role_id, user_id: user_id, guild_id: guild_id}}
        {:error, {status, message}} ->
          Logger.error("Failed to assign role #{role_id} to user #{user_id} in guild #{guild_id}: #{inspect({status, message})}")
          {:error, {status, message}}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.get(params, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
