defmodule Lux.Prisms.Discord.Voice.LeaveVoiceChannel do
  @moduledoc """
  Leave the current voice channel in a Discord guild.

  Uses the Discord API to leave a voice channel via PATCH request.
  Setting channel_id to nil leaves the current channel.

  ## Examples

      iex> LeaveVoiceChannel.handler(%{guild_id: "123456789"}, %{name: "Agent"})
      {:ok, %{left: true, guild_id: "123456789"}}
  """

  use Lux.Prism,
    name: "Leave Discord Voice Channel",
    description: "Leaves the current voice channel in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild",
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
          description: "Whether the bot successfully left the voice channel"
        },
        guild_id: %{
          type: :string,
          description: "The guild ID"
        }
      },
      required: ["left"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Leaves the current voice channel in a Discord guild.

  Returns {:ok, %{left: true, guild_id: id}} on success.
  Returns {:error, {status, message}} on failure.
  """
  @spec handler(map(), map()) :: {:ok, map()} | {:error, any()}
  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} leaving voice channel in guild #{guild_id}")

      body = %{"channel_id" => nil}

      case Client.request(:patch, "/guilds/#{guild_id}/voice-states/@me", %{json: body}) do
        {:ok, _} ->
          Logger.info("Successfully left voice channel in guild #{guild_id}")
          {:ok, %{left: true, guild_id: guild_id}}

        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to leave voice channel in guild #{guild_id}: #{inspect(error)}")
          {:error, error}

        {:error, error} ->
          Logger.error("Failed to leave voice channel in guild #{guild_id}: #{inspect(error)}")
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
