defmodule Lux.Prisms.Discord.Server.JoinServer do
  @moduledoc """
  A prism for joining a Discord server via invite.

  Joins a guild using an invite code. The bot's token must have
  the appropriate OAuth2 scope (guilds.join).
  """

  use Lux.Prism,
    name: "Join Discord Server",
    description: "Joins a Discord server using an invite code",
    input_schema: %{
      type: :object,
      properties: %{
        invite_code: %{
          type: :string,
          description: "The Discord invite code (e.g., 'abc123' from discord.gg/abc123)",
          minLength: 1,
          maxLength: 100
        }
      },
      required: ["invite_code"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        joined: %{
          type: :boolean,
          description: "Whether the join was successful"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the joined guild"
        },
        guild_name: %{
          type: :string,
          description: "The name of the joined guild"
        }
      },
      required: ["joined"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to join a Discord server via invite.
  """
  def handler(params, agent) do
    with {:ok, invite_code} <- Lux.Prisms.Discord.Helpers.validate_string(params, :invite_code) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} joining server with invite: #{invite_code}")

      case Client.request(:post, "/invites/#{invite_code}", %{
        json: %{}
      }) do
        {:ok, %{"guild" => %{"id" => guild_id, "name" => guild_name}}} ->
          Logger.info("Successfully joined server #{guild_name} (#{guild_id})")
          {:ok, %{joined: true, guild_id: guild_id, guild_name: guild_name}}
        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to join server with invite #{invite_code}: #{inspect(error)}")
          {:error, error}
        {:error, error} ->
          Logger.error("Failed to join server with invite #{invite_code}: #{inspect(error)}")
          {:error, error}
      end
    end
  end
end