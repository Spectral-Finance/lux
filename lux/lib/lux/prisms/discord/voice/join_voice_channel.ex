defmodule Lux.Prisms.Discord.Voice.JoinVoiceChannel do
  @moduledoc """
  Join a voice channel in a Discord guild.

  Uses the Discord API to join a specified voice channel via PATCH request.
  Requires bot to have Connect permission in the channel.

  ## Examples

      iex> JoinVoiceChannel.handler(%{
      ...>   guild_id: "123456789",
      ...>   channel_id: "987654321"
      ...> }, %{name: "Agent"})
      {:ok, %{
        joined: true,
        guild_id: "123456789",
        channel_id: "987654321"
      }}
  """

  use Lux.Prism,
    name: "Join Discord Voice Channel",
    description: "Joins a specified voice channel in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild",
          pattern: "^[0-9]{17,20}$"
        },
        channel_id: %{
          type: :string,
          description: "The ID of the voice channel to join",
          pattern: "^[0-9]{17,20}$"
        },
        self_mute: %{
          type: :boolean,
          description: "Whether the bot is self-muted"
        },
        self_deaf: %{
          type: :boolean,
          description: "Whether the bot is self-deafened"
        }
      },
      required: ["guild_id", "channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        joined: %{
          type: :boolean,
          description: "Whether the bot successfully joined the voice channel"
        },
        guild_id: %{
          type: :string,
          description: "The guild ID"
        },
        channel_id: %{
          type: :string,
          description: "The channel ID joined"
        }
      },
      required: ["joined"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Joins a voice channel in a Discord guild.

  Returns {:ok, %{joined: true, guild_id: id, channel_id: id}} on success.
  Returns {:error, {status, message}} on failure.
  """
  @spec handler(map(), map()) :: {:ok, map()} | {:error, any()}
  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, channel_id} <- validate_param(params, :channel_id) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} joining voice channel #{channel_id} in guild #{guild_id}")

      body = %{
        "channel_id" => channel_id,
        "self_mute" => Map.get(params, :self_mute, false),
        "self_deaf" => Map.get(params, :self_deaf, false)
      }

      case Client.request(:patch, "/guilds/#{guild_id}/voice-states/@me", %{json: body}) do
        {:ok, %{"channel_id" => returned_channel}} ->
          Logger.info("Successfully joined voice channel #{returned_channel} in guild #{guild_id}")
          {:ok, %{joined: true, guild_id: guild_id, channel_id: channel_id}}

        {:error, {status, %{"message" => message}}} ->
          error = {status, message}
          Logger.error("Failed to join voice channel in guild #{guild_id}: #{inspect(error)}")
          {:error, error}

        {:error, error} ->
          Logger.error("Failed to join voice channel in guild #{guild_id}: #{inspect(error)}")
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
