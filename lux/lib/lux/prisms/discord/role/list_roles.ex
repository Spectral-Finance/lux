defmodule Lux.Prisms.Discord.Role.ListRoles do
  @moduledoc """
  A prism for listing all roles in a Discord guild.

  Returns roles sorted by hierarchy (highest first).
  """

  use Lux.Prism,
    name: "List Guild Roles",
    description: "Lists all roles in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to list roles for",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        roles: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              id: %{type: :string},
              name: %{type: :string},
              color: %{type: :integer},
              hoist: %{type: :boolean},
              position: %{type: :integer},
              permissions: %{type: :string},
              managed: %{type: :boolean},
              mentionable: %{type: :boolean},
              tags: %{type: :object, nullable: true}
            }
          }
        }
      },
      required: ["roles"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Lists all roles in a Discord guild.
  """
  def handler(params, agent) do
    with {:ok, guild_id} <- Lux.Prisms.Discord.Helpers.validate_string(params, :guild_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} listing roles of guild #{guild_id}")

      case Client.request(:get, "/guilds/#{guild_id}/roles") do
        {:ok, roles} ->
          Logger.info("Found #{length(roles)} roles in guild #{guild_id}")
          {:ok, %{roles: roles}}
        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to list roles of guild #{guild_id}: #{inspect(error)}")
          {:error, error}
        {:error, error} ->
          Logger.error("Failed to list roles of guild #{guild_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end
end