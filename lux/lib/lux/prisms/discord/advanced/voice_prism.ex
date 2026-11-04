defmodule Lux.Prisms.Discord.Advanced.VoicePrism do
  @moduledoc """
  A prism for managing voice channel connections, audio streaming, and voice activity detection (VAD).
  """

  use Lux.Prism,
    name: "Discord Advanced Voice Prism",
    description: "Manages voice channel connections, audio streaming, and Voice Activity Detection",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["connect", "disconnect", "stream", "detect_vad", "status"],
          default: "status"
        },
        guild_id: %{type: :string},
        channel_id: %{type: :string},
        audio_source: %{type: :string},
        amplitude: %{type: :number, default: 0.08}
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        guild_id: %{type: :string},
        result: %{type: [:object, :string, :null]},
        status: %{type: :string}
      },
      required: ["action", "guild_id", "status"]
    }

  alias Lux.Discord.Voice

  @impl true
  def handler(inputs, _context) do
    action = Map.get(inputs, "action") || Map.get(inputs, :action, "status")
    guild_id = Map.get(inputs, "guild_id") || Map.get(inputs, :guild_id)

    case action do
      "connect" ->
        channel_id = Map.get(inputs, "channel_id") || Map.get(inputs, :channel_id, "voice_01")
        {:ok, session} = Voice.connect_channel(guild_id, channel_id)
        {:ok, %{action: "connect", guild_id: guild_id, result: session, status: "connected"}}

      "disconnect" ->
        Voice.disconnect_channel(guild_id)
        {:ok, %{action: "disconnect", guild_id: guild_id, result: nil, status: "disconnected"}}

      "stream" ->
        audio = Map.get(inputs, "audio_source") || Map.get(inputs, :audio_source, "https://audio.example.com/stream.mp3")
        case Voice.stream_audio(guild_id, audio) do
          {:ok, stream_info} ->
            {:ok, %{action: "stream", guild_id: guild_id, result: stream_info, status: "streaming"}}

          {:error, reason} ->
            # Auto-connect if not connected for prism convenience
            Voice.connect_channel(guild_id, "default_voice")
            {:ok, stream_info} = Voice.stream_audio(guild_id, audio)
            {:ok, %{action: "stream", guild_id: guild_id, result: stream_info, status: "streaming"}}
        end

      "detect_vad" ->
        amp = Map.get(inputs, "amplitude") || Map.get(inputs, :amplitude, 0.08)
        {:ok, speaking, level} = Voice.detect_voice_activity(amp)
        {:ok, %{action: "detect_vad", guild_id: guild_id, result: %{speaking: speaking, level: level}, status: "ok"}}

      _status ->
        case Voice.get_connection_state(guild_id) do
          {:ok, state} ->
            {:ok, %{action: "status", guild_id: guild_id, result: state, status: to_string(state.status)}}

          {:error, _} ->
            {:ok, %{action: "status", guild_id: guild_id, result: nil, status: "disconnected"}}
        end
    end
  end
end
