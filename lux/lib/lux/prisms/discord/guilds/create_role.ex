defmodule Lux.Prisms.Discord.Guilds.CreateRole do
  @moduledoc """
  A prism for creating roles in a Discord guild.

  Supports:
  - Name, color, permissions
  - Hoist (display separately), mentionable
  - Optional icon for Nitro roles

  ## Examples
      iex> CreateRole.handler(%{
      ...>   guild_id: "123456789",
      ...>   name: "Moderator",
      ...>   color: 3447003,
      ...>   hoist: true,
      ...>   mentionable: true
      ...> }, %{name: "Agent"})
      {:ok, %{
        created: true,
        role_id: "111111111111111111",
        name: "Moderator",
        color: 3447003
      }}
  """

  use Lux.Prism,
    name: "Create Discord Role",
    description: "Creates a new role in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to create the role in",
          pattern: "^[0-9]{17,20}$"
        },
        name: %{
          type: :string,
          description: "The name of the role (1-100 characters)",
          minLength: 1,
          maxLength: 100
        },
        permissions: %{
          type: :string,
          description: "Bitwise permission value for the role"
        },
        color: %{
          type: :integer,
          description: "RGB color value for the role (0-16777215)",
          minimum: 0,
          maximum: 16_777_215
        },
        hoist: %{
          type: :boolean,
          description: "Whether to display the role separately in the sidebar",
          default: false
        },
        mentionable: %{
          type: :boolean,
          description: "Whether the role is mentionable",
          default: false
        }
      },
      required: ["guild_id", "name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{
          type: :boolean,
          description: "Whether the role was successfully created"
        },
        role_id: %{
          type: :string,
          description: "The ID of the created role"
        },
        name: %{
          type: :string,
          description: "The name of the created role"
        },
        color: %{
          type: :integer,
          description: "The color of the created role"
        }
      },
      required: ["created"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, name} <- validate_param(params, :name) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} creating role #{name} in guild #{guild_id}")

      body =
        %{name: name}
        |> maybe_add(:permissions, params)
        |> maybe_add(:color, params)
        |> maybe_add(:hoist, params)
        |> maybe_add(:mentionable, params)

      case Client.request(:post, "/guilds/#{guild_id}/roles", %{json: body}) do
        {:ok, %{"id" => role_id, "name" => name, "color" => color}} ->
          Logger.info("Successfully created role #{role_id} in guild #{guild_id}")
          {:ok, %{created: true, role_id: role_id, name: name, color: color}}

        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to create role in guild #{guild_id}: #{inspect(error)}")
          {:error, error}

        {:error, error} ->
          Logger.error("Failed to create role in guild #{guild_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp maybe_add(map, key, params) do
    case Map.fetch(params, key) do
      {:ok, value} when not is_nil(value) -> Map.put(map, key, value)
      _ -> map
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
