defmodule Lux.Prisms.Discord.Roles.AssignRole do
  @moduledoc """
  A prism for assigning a role to a Discord server member.

  ## Examples

      iex> AssignRole.handler(%{
      ...>   guild_id: "111111111111111111",
      ...>   user_id: "222222222222222222",
      ...>   role_id: "333333333333333333"
      ...> }, %{name: "Agent"})
      {:ok, %{assigned: true, user_id: "222222222222222222", role_id: "333333333333333333"}}
  """

  use Lux.Prism,
    name: "Assign Discord Role",
    description: "Assigns a role to a member in a Discord server",
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
          description: "The ID of the user to assign the role to",
          pattern: "^[0-9]{17,20}$"
        },
        role_id: %{
          type: :string,
          description: "The ID of the role to assign",
          pattern: "^[0-9]{17,20}$"
        },
        reason: %{
          type: :string,
          description: "Optional audit log reason for the role assignment",
          maxLength: 500
        }
      },
      required: ["guild_id", "user_id", "role_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        assigned: %{type: :boolean, description: "Whether the role was successfully assigned"},
        user_id: %{type: :string, description: "The ID of the user"},
        role_id: %{type: :string, description: "The ID of the assigned role"}
      },
      required: ["assigned"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, user_id} <- validate_param(params, :user_id),
         {:ok, role_id} <- validate_param(params, :role_id),
         {:ok, reason} <- validate_optional_param(params, :reason) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} assigning role #{role_id} to user #{user_id} in server #{guild_id}")

      opts = if reason, do: %{headers: [{"X-Audit-Log-Reason", reason}]}, else: %{}

      case Client.request(:put, "/guilds/#{guild_id}/members/#{user_id}/roles/#{role_id}", opts) do
        {:ok, _} ->
          Logger.info("Successfully assigned role #{role_id} to user #{user_id}")
          {:ok, %{assigned: true, user_id: user_id, role_id: role_id}}

        {:error, %{"status" => 204}} ->
          Logger.info("Successfully assigned role #{role_id} to user #{user_id} (204)")
          {:ok, %{assigned: true, user_id: user_id, role_id: role_id}}

        error ->
          Logger.error("Failed to assign role: #{inspect(error)}")
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

  defp validate_optional_param(params, key, default \\ nil) do
    case Map.get(params, key, default) do
      nil -> {:ok, nil}
      value -> {:ok, value}
    end
  end
end
