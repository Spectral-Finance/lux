defmodule Lux.Prisms.Discord.Member.ListMembers do
  @moduledoc """
  A prism for listing members of a Discord guild.

  Supports pagination with limit and after parameters.
  """

  use Lux.Prism,
    name: "List Guild Members",
    description: "Lists members of a Discord guild with pagination",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to list members for",
          pattern: "^[0-9]{17,20}$"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of members to return (1-1000)",
          minimum: 1,
          maximum: 1000,
          default: 100
        },
        after: %{
          type: :string,
          description: "Return members after this user ID",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        members: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              user: %{
                type: :object,
                properties: %{
                  id: %{type: :string},
                  username: %{type: :string},
                  discriminator: %{type: :string},
                  avatar: %{type: :string, nullable: true},
                  bot: %{type: :boolean}
                }
              },
              roles: %{type: :array, items: %{type: :string}},
              joined_at: %{type: :string},
              nick: %{type: :string, nullable: true},
              premium_since: %{type: :string, nullable: true}
            }
          }
        }
      },
      required: ["members"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Lists members of a Discord guild with pagination.
  """
  def handler(params, agent) do
    with {:ok, guild_id} <- Lux.Prisms.Discord.Helpers.validate_string(params, :guild_id),
         {:ok, limit} <- Lux.Prisms.Discord.Helpers.validate_integer(params, :limit, [default: 100, min: 1, max: 1000]),
         {:ok, after} <- Lux.Prisms.Discord.Helpers.optional(params, :after) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} listing members of guild #{guild_id} (limit: #{limit})")

      query = "limit=#{limit}"
      query = if after, do: query <> "&after=#{after}", else: query

      case Client.request(:get, "/guilds/#{guild_id}/members?#{query}") do
        {:ok, members} ->
          Logger.info("Found #{length(members)} members in guild #{guild_id}")
          {:ok, %{members: members}}
        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to list members of guild #{guild_id}: #{inspect(error)}")
          {:error, error}
        {:error, error} ->
          Logger.error("Failed to list members of guild #{guild_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end
end