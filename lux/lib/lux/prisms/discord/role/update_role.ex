defmodule Lux.Prisms.Discord.Role.UpdateRole do
  @moduledoc """
  A prism for updating Discord role metadata and permission settings.
  """

  use Lux.Prism,
    name: "Update Discord Role",
    description: "Updates a role's name, permission flags, and display settings",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Guild ID", pattern: "^[0-9]{17,20}$"},
        role_id: %{type: :string, description: "Role ID", pattern: "^[0-9]{17,20}$"},
        name: %{type: :string, description: "Role name", minLength: 1, maxLength: 100},
        permissions: %{type: :string, description: "Discord permission bitset"},
        color: %{type: :integer, description: "Role color as an integer"},
        hoist: %{type: :boolean, description: "Show role separately in the member list"},
        mentionable: %{type: :boolean, description: "Allow users to mention this role"}
      },
      required: ["guild_id", "role_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        updated: %{type: :boolean},
        role_id: %{type: :string},
        name: %{type: :string},
        permissions: %{type: :string},
        position: %{type: :integer}
      },
      required: ["updated"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @mutable_fields [:name, :permissions, :color, :hoist, :mentionable]

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, role_id} <- validate_param(params, :role_id),
         {:ok, body} <- build_body(params) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} updating role #{role_id} in guild #{guild_id}")

      case Client.request(:patch, "/guilds/#{guild_id}/roles/#{role_id}", %{json: body}) do
        {:ok, role} ->
          Logger.info("Successfully updated role #{role_id} in guild #{guild_id}")

          {:ok,
           %{
             updated: true,
             role_id: role["id"] || role_id,
             name: role["name"],
             permissions: role["permissions"],
             position: role["position"]
           }}

        error ->
          Logger.error("Failed to update role #{role_id} in guild #{guild_id}: #{inspect(error)}")
          error
      end
    end
  end

  defp build_body(params) do
    body =
      @mutable_fields
      |> Enum.filter(&Map.has_key?(params, &1))
      |> Enum.reject(&is_nil(params[&1]))
      |> Map.new(&{&1, params[&1]})

    case body do
      empty when empty == %{} -> {:error, "At least one role field is required"}
      _ -> {:ok, body}
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
