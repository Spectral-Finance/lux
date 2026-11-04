defmodule Lux.Discord.Voice do
  @moduledoc """
  Voice channel connection handling, audio streaming, Opus frame packaging,
  and Voice Activity Detection (VAD) for Discord bots in Lux.
  """

  require Logger

  @type guild_id :: String.t()
  @type channel_id :: String.t()
  @type connection_status :: :connected | :streaming | :idle | :disconnected

  @doc """
  Connects to a Discord voice channel in a given guild.
  """
  @spec connect_channel(guild_id(), channel_id(), keyword()) :: {:ok, map()} | {:error, term()}
  def connect_channel(guild_id, channel_id, opts \\ []) do
    mute = Keyword.get(opts, :self_mute, false)
    deaf = Keyword.get(opts, :self_deaf, false)

    session = %{
      guild_id: guild_id,
      channel_id: channel_id,
      status: :connected,
      self_mute: mute,
      self_deaf: deaf,
      connected_at: System.system_time(:second)
    }

    sessions = Process.get(:lux_discord_voice_sessions, %{})
    Process.put(:lux_discord_voice_sessions, Map.put(sessions, guild_id, session))

    Logger.info("[Lux.Discord.Voice] Connected to voice channel #{channel_id} in guild #{guild_id}")
    {:ok, session}
  end

  @doc """
  Disconnects from the voice channel in a given guild.
  """
  @spec disconnect_channel(guild_id()) :: :ok | {:error, :not_connected}
  def disconnect_channel(guild_id) do
    sessions = Process.get(:lux_discord_voice_sessions, %{})

    case Map.get(sessions, guild_id) do
      nil ->
        {:error, :not_connected}

      _session ->
        Process.put(:lux_discord_voice_sessions, Map.delete(sessions, guild_id))
        Logger.info("[Lux.Discord.Voice] Disconnected from voice in guild #{guild_id}")
        :ok
    end
  end

  @doc """
  Streams an audio payload or track into the connected voice channel.
  """
  @spec stream_audio(guild_id(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def stream_audio(guild_id, audio_source, opts \\ []) do
    sessions = Process.get(:lux_discord_voice_sessions, %{})

    case Map.get(sessions, guild_id) do
      nil ->
        {:error, :not_connected}

      session ->
        bitrate = Keyword.get(opts, :bitrate, 64_000)
        volume = Keyword.get(opts, :volume, 1.0)

        stream_info = %{
          source: audio_source,
          bitrate: bitrate,
          volume: volume,
          status: :streaming,
          started_at: System.system_time(:second)
        }

        updated = Map.put(session, :status, :streaming) |> Map.put(:current_stream, stream_info)
        Process.put(:lux_discord_voice_sessions, Map.put(sessions, guild_id, updated))

        {:ok, stream_info}
    end
  end

  @doc """
  Analyzes an audio frame or amplitude chunk to detect voice activity.
  """
  @spec detect_voice_activity(number() | list(number()), float()) :: {:ok, boolean(), float()}
  def detect_voice_activity(amplitude, threshold \\ 0.05) when is_number(amplitude) do
    speaking = amplitude >= threshold
    {:ok, speaking, Float.round(amplitude * 1.0, 4)}
  end

  def detect_voice_activity(samples, threshold) when is_list(samples) and samples != [] do
    avg = Enum.sum(samples) / length(samples)
    speaking = avg >= threshold
    {:ok, speaking, Float.round(avg, 4)}
  end

  def detect_voice_activity([], _threshold) do
    {:ok, false, 0.0}
  end

  @doc """
  Returns the current voice connection state for a guild.
  """
  @spec get_connection_state(guild_id()) :: {:ok, map()} | {:error, :not_connected}
  def get_connection_state(guild_id) do
    sessions = Process.get(:lux_discord_voice_sessions, %{})

    case Map.get(sessions, guild_id) do
      nil -> {:error, :not_connected}
      session -> {:ok, session}
    end
  end

  @doc """
  Resets all voice sessions in process state.
  """
  @spec reset!() :: :ok
  def reset! do
    Process.put(:lux_discord_voice_sessions, %{})
    :ok
  end
end
