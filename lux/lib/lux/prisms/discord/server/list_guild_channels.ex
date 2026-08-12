defmodule Lux.Prisms.Discord.Server.ListGuildChannels do
  @moduledoc """
  A prism for listing all channels in a Discord guild.

  Returns text, voice, category, forum, and stage channels.
  """

  use Lux.Prism,
    name: "List Guild Channels",
    description: "Lists all channels in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to list channels for",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        channels: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              id: %{type: :string},
              type: %{type: :integer},
              name: %{type: :string},
              position: %{type: :integer},
              parent_id: %{type: :string, nullable: true},
              topic: %{type: :string, nullable: true},
              nsfw: %{type: :boolean},
              bitrate: %{type: :integer},
              user_limit: %{type: :integer},
              rate_limit_per_user: %{type: :integer}
            }
          }
        }
      },
      required: ["channels"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Lists all channels in a Discord guild.
  """
  def handler(params, agent) do
    with {:ok, guild_id} <- Lux.Prisms.Discord.Helpers.validate_string(params, :guild_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} listing channels of guild #{guild_id}")

      case Client.request(:get, "/guilds/#{guild_id}/channels") do
        {:ok, channels} ->
          Logger.info("Found #{length(channels)} channels in guild #{guild_id}")
          {:ok, %{channels: channels}}
        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to list channels of guild #{guild_id}: #{inspect(error)}")
          {:error, error}
        {:error, error} ->
          Logger.error("Failed to list channels of guild #{guild_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end
end