defmodule Lux.Prisms.Discord.Roles.AddRole do
  @moduledoc """
  A prism for adding a role to a member in a Discord guild.

  This prism provides an interface for adding a role with:
  - Required parameters (guild_id, user_id, role_id)
  - Success/failure response structure
  """

  use Lux.Prism,
    name: "Add Discord Role to Member",
    description: "Adds a specific role to a member in a Discord guild",
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
          description: "The ID of the role to add",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id", "user_id", "role_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        added: %{
          type: :boolean,
          description: "Whether the role was successfully added"
        },
        guild_id: %{type: :string},
        user_id: %{type: :string},
        role_id: %{type: :string}
      },
      required: ["added"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to add a role to a member.
  """
  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, user_id} <- validate_param(params, :user_id),
         {:ok, role_id} <- validate_param(params, :role_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} adding role #{role_id} to member #{user_id} in guild #{guild_id}")

      req_opts = Map.take(params, [:plug])

      case Client.request(
             :put,
             "/guilds/#{guild_id}/members/#{user_id}/roles/#{role_id}",
             req_opts
           ) do
        {:ok, _body} ->
          Logger.info("Successfully added role #{role_id} to member #{user_id} in guild #{guild_id}")
          {:ok, %{added: true, guild_id: guild_id, user_id: user_id, role_id: role_id}}

        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to add role: #{inspect(error)}")
          {:error, error}

        {:error, error} ->
          Logger.error("Failed to add role: #{inspect(error)}")
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
