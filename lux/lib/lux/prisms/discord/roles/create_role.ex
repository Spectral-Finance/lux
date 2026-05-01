defmodule Lux.Prisms.Discord.Roles.CreateRole do
  @moduledoc """
  A prism for creating a custom role in a Discord server.

  ## Examples

      iex> CreateRole.handler(%{
      ...>   guild_id: "111111111111111111",
      ...>   name: "Moderator",
      ...>   permissions: 8,
      ...>   color: 3447003,
      ...>   hoist: true,
      ...>   mentionable: true
      ...> }, %{name: "Agent"})
      {:ok, %{created: true, role_id: "444444444444444444", name: "Moderator"}}
  """

  use Lux.Prism,
    name: "Create Discord Role",
    description: "Creates a custom role in a Discord server",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the server",
          pattern: "^[0-9]{17,20}$"
        },
        name: %{
          type: :string,
          description: "The name of the role",
          minLength: 1,
          maxLength: 100
        },
        permissions: %{
          type: :integer,
          description: "Permission bitset value (e.g., 8 for Administrator, 0x8 for ManageChannels)",
          minimum: 0
        },
        color: %{
          type: :integer,
          description: "RGB color value for the role",
          minimum: 0,
          maximum: 16777215
        },
        hoist: %{
          type: :boolean,
          description: "Whether the role should be displayed separately in the sidebar",
          default: false
        },
        mentionable: %{
          type: :boolean,
          description: "Whether the role can be mentioned",
          default: false
        },
        reason: %{
          type: :string,
          description: "Optional audit log reason",
          maxLength: 500
        }
      },
      required: ["guild_id", "name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{type: :boolean, description: "Whether the role was successfully created"},
        role_id: %{type: :string, description: "The ID of the created role"},
        name: %{type: :string, description: "The name of the created role"}
      },
      required: ["created"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, name} <- validate_param(params, :name),
         {:ok, permissions} <- validate_optional_param(params, :permissions),
         {:ok, color} <- validate_optional_param(params, :color),
         {:ok, hoist} <- validate_optional_param(params, :hoist, false),
         {:ok, mentionable} <- validate_optional_param(params, :mentionable, false) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} creating role #{name} in server #{guild_id}")

      body = %{name: name, hoist: hoist, mentionable: mentionable}
        |> maybe_add_param(:permissions, permissions)
        |> maybe_add_param(:color, color)

      case Client.request(:post, "/guilds/#{guild_id}/roles", %{json: body}) do
        {:ok, %{"id" => role_id, "name" => role_name}} ->
          Logger.info("Successfully created role #{role_name} (#{role_id})")
          {:ok, %{created: true, role_id: role_id, name: role_name}}
        error ->
          Logger.error("Failed to create role: #{inspect(error)}")
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

  defp maybe_add_param(map, _key, nil), do: map
  defp maybe_add_param(map, key, value), do: Map.put(map, key, value)
end
