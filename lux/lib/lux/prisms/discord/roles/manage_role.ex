defmodule Lux.Prisms.Discord.Roles.ManageRole do
  @moduledoc """
  A prism for managing Discord guild roles and permissions (`Spectral-Finance/lux#55`).

  Supports:
  - Custom role creation (`action: "create"`)
  - Role assignment to guild members (`action: "assign"`)
  - Role removal from guild members (`action: "revoke"`)
  - Permission and hierarchy updates (`action: "update"`)

  ## Examples

      iex> ManageRole.handler(%{
      ...>   action: "create",
      ...>   guild_id: "123456789012345678",
      ...>   name: "DeFi Strategist",
      ...>   permissions: "8"
      ...> }, %{name: "DiscordAgent"})
      {:ok, %{success: true, action: "create", role_id: "999999999999999999", guild_id: "123456789012345678"}}
  """

  use Lux.Prism,
    name: "Manage Discord Role",
    description: "Creates, updates, assigns, or revokes roles and permissions in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Role operation to perform (create, update, assign, revoke)",
          enum: ["create", "update", "assign", "revoke"]
        },
        guild_id: %{
          type: :string,
          description: "The ID of the Discord guild",
          pattern: "^[0-9]{17,20}$"
        },
        role_id: %{
          type: :string,
          description: "Target role ID (required for update, assign, revoke)"
        },
        user_id: %{
          type: :string,
          description: "Target member user ID (required for assign, revoke)"
        },
        name: %{
          type: :string,
          description: "Role name (for create or update)"
        },
        permissions: %{
          type: :string,
          description: "Bitwise permission string"
        }
      },
      required: ["action", "guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{type: :boolean},
        action: %{type: :string},
        guild_id: %{type: :string},
        role_id: %{type: :string},
        user_id: %{type: :string}
      },
      required: ["success", "action", "guild_id"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @impl true
  def handler(params, agent) do
    agent_name = agent[:name] || "DiscordAgent"
    action = params[:action] || params["action"]
    guild_id = params[:guild_id] || params["guild_id"]

    cond do
      !is_binary(guild_id) or guild_id == "" ->
        {:error, "Missing or invalid guild_id"}

      action == "create" ->
        name = params[:name] || params["name"] || "New Role"
        permissions = params[:permissions] || params["permissions"] || "0"
        Logger.info("Agent #{agent_name} creating role #{name} in guild #{guild_id}")

        case Client.request(:post, "/guilds/#{guild_id}/roles", %{
               json: %{name: name, permissions: permissions}
             }) do
          {:ok, %{"id" => role_id}} ->
            {:ok, %{success: true, action: "create", guild_id: guild_id, role_id: role_id, name: name}}

          {:error, err} ->
            {:error, err}
        end

      action in ["assign", "revoke"] ->
        user_id = params[:user_id] || params["user_id"]
        role_id = params[:role_id] || params["role_id"]

        if is_binary(user_id) and is_binary(role_id) do
          method = if action == "assign", do: :put, else: :delete
          path = "/guilds/#{guild_id}/members/#{user_id}/roles/#{role_id}"

          case Client.request(method, path, %{}) do
            {:ok, _} ->
              {:ok, %{success: true, action: action, guild_id: guild_id, role_id: role_id, user_id: user_id}}

            {:error, err} ->
              {:error, err}
          end
        else
          {:error, "Missing user_id or role_id for #{action}"}
        end

      action == "update" ->
        role_id = params[:role_id] || params["role_id"]
        name = params[:name] || params["name"]
        permissions = params[:permissions] || params["permissions"]

        if is_binary(role_id) do
          case Client.request(:patch, "/guilds/#{guild_id}/roles/#{role_id}", %{
                 json: %{name: name, permissions: permissions}
               }) do
            {:ok, %{"id" => updated_id}} ->
              {:ok, %{success: true, action: "update", guild_id: guild_id, role_id: updated_id}}

            {:error, err} ->
              {:error, err}
          end
        else
          {:error, "Missing role_id for update"}
        end

      true ->
        {:error, "Unsupported role action: #{inspect(action)}"}
    end
  end
end
