defmodule Lux.Prisms.Discord.Voice.UpdateVoiceState do
  @moduledoc """
  A prism for updating Discord voice state.

  Joins, moves to, or disconnects from a voice channel.

  ## Examples

      iex> UpdateVoiceState.handler(%{guild_id: "g1", channel_id: "vc1"}, %{name: "Agent"})
      {:ok, %{joined: true, guild_id: "g1", channel_id: "vc1"}}

      iex> UpdateVoiceState.handler(%{guild_id: "g1", channel_id: nil}, %{name: "Agent"})
      {:ok, %{disconnected: true, guild_id: "g1"}}

  """

  use Lux.Prism,
    name: "Update Discord Voice State",
    description: "Joins, moves, or disconnects from a voice channel",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "The guild ID", pattern: "^[0-9]{17,20}$"},
        channel_id: %{type: [:string, :null], description: "Channel ID to join, nil to disconnect"},
        self_mute: %{type: :boolean, description: "Join muted"},
        self_deaf: %{type: :boolean, description: "Join deafened"}
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        joined: %{type: :boolean},
        disconnected: %{type: :boolean},
        guild_id: %{type: :string},
        channel_id: %{type: [:string, :null]}
      }
    }

  alias Lux.Integrations.Discord.Voice
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id) do
      agent_name = agent[:name] || "Unknown Agent"
      channel_id = Map.get(params, :channel_id)
      self_mute = Map.get(params, :self_mute, false)
      self_deaf = Map.get(params, :self_deaf, false)

      if channel_id do
        Logger.info("Agent #{agent_name} joining voice channel #{channel_id} in guild #{guild_id}")
      else
        Logger.info("Agent #{agent_name} disconnecting from voice in guild #{guild_id}")
      end

      opts = %{self_mute: self_mute, self_deaf: self_deaf}

      case Voice.update_voice_state(guild_id, channel_id, opts) do
        {:ok, _result} ->
          if channel_id do
            Logger.info("Joined voice channel #{channel_id} in guild #{guild_id}")
            {:ok, %{joined: true, disconnected: false, guild_id: guild_id, channel_id: channel_id}}
          else
            Logger.info("Disconnected from voice in guild #{guild_id}")
            {:ok, %{joined: false, disconnected: true, guild_id: guild_id, channel_id: nil}}
          end

        {:error, error} ->
          Logger.error("Failed to update voice state in guild #{guild_id}: #{inspect(error)}")
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
