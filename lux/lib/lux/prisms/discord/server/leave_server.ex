defmodule Lux.Prisms.Discord.Server.LeaveServer do
  @moduledoc """
  A prism for leaving a Discord server.

  Leaves a guild the bot is currently a member of.
  """

  use Lux.Prism,
    name: "Leave Discord Server",
    description: "Leaves a Discord server (guild)",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to leave",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        left: %{
          type: :boolean,
          description: "Whether the leave was successful"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the guild that was left"
        }
      },
      required: ["left"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to leave a Discord server.
  """
  def handler(params, agent) do
    with {:ok, guild_id} <- Lux.Prisms.Discord.Helpers.validate_string(params, :guild_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} leaving server #{guild_id}")

      case Client.request(:delete, "/users/@me/guilds/#{guild_id}") do
        {:ok, _} ->
          Logger.info("Successfully left server #{guild_id}")
          {:ok, %{left: true, guild_id: guild_id}}
        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to leave server #{guild_id}: #{inspect(error)}")
          {:error, error}
        {:error, error} ->
          Logger.error("Failed to leave server #{guild_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end
end