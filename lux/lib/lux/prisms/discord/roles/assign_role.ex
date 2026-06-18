defmodule Lux.Prisms.Discord.Roles.AssignRole do
  @moduledoc """
  A prism for assigning and removing roles from Discord members.

  Supports:
  - Adding a role to a member
  - Removing a role from a member
  - Checking if a member has a specific role

  ## Examples
      iex> AssignRole.handler(%{
      ...>   guild_id: "123456789",
      ...>   user_id: "987654321",
      ...>   role_id: "555555555555555555",
      ...>   action: "add"
      ...> }, %{name: "Agent"})
      {:ok, %{
        action: "add",
        success: true,
        user_id: "987654321",
        role_id: "555555555555555555",
        guild_id: "123456789"
      }}

      iex> AssignRole.handler(%{
      ...>   guild_id: "123456789",
      ...>   user_id: "987654321",
      ...>   role_id: "555555555555555555",
      ...>   action: "remove"
      ...> }, %{name: "Agent"})
      {:ok, %{
        action: "remove",
        success: true,
        user_id: "987654321",
        role_id: "555555555555555555"
      }}
  """

  use Lux.Prism,
    name: "Assign Discord Role",
    description: "Adds or removes a role from a Discord guild member",
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
          description: "The ID of the user to modify",
          pattern: "^[0-9]{17,20}$"
        },
        role_id: %{
          type: :string,
          description: "The ID of the role to assign or remove",
          pattern: "^[0-9]{17,20}$"
        },
        action: %{
          type: :string,
          description: "Action to perform: add or remove",
          enum: ["add", "remove"]
        }
      },
      required: ["guild_id", "user_id", "role_id", "action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "The action that was performed"
        },
        success: %{
          type: :boolean,
          description: "Whether the action succeeded"
        },
        user_id: %{
          type: :string,
          description: "The ID of the affected user"
        },
        role_id: %{
          type: :string,
          description: "The ID of the role"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the guild"
        }
      },
      required: ["action", "success"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, user_id} <- validate_param(params, :user_id),
         {:ok, role_id} <- validate_param(params, :role_id),
         {:ok, action} <- validate_param(params, :action) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} performing role action '#{action}' for user #{user_id} in guild #{guild_id}")

      case action do
        "add" ->
          case Client.request(:put, "/guilds/#{guild_id}/members/#{user_id}/roles/#{role_id}") do
            {:ok, _} ->
              Logger.info("Successfully added role #{role_id} to user #{user_id}")
              {:ok, %{action: "add", success: true, user_id: user_id, role_id: role_id, guild_id: guild_id}}

            {:error, {status, %{"message" => message}}} ->
              {:error, {status, message}}

            {:error, error} ->
              {:error, error}
          end

        "remove" ->
          case Client.request(:delete, "/guilds/#{guild_id}/members/#{user_id}/roles/#{role_id}") do
            {:ok, _} ->
              Logger.info("Successfully removed role #{role_id} from user #{user_id}")
              {:ok, %{action: "remove", success: true, user_id: user_id, role_id: role_id, guild_id: guild_id}}

            {:error, {status, %{"message" => message}}} ->
              {:error, {status, message}}

            {:error, error} ->
              {:error, error}
          end
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
