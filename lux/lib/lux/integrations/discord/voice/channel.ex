defmodule Lux.Integrations.Discord.Voice.Channel do
  @moduledoc """
  Handles Discord voice channel connections and management.
  Provides functionality for joining, leaving, and managing voice channels.
  """

  require Logger

  alias Lux.Integrations.Discord.Voice.Connection

  @type t :: %__MODULE__{
    guild_id: String.t(),
    channel_id: String.t(),
    session_id: String.t() | nil,
    token: String.t() | nil,
    endpoint: String.t() | nil,
    connected: boolean(),
    streaming: boolean(),
    speaking: boolean(),
    audio_queue: :queue.queue(),
    connection_pid: pid() | nil
  }

  defstruct [
    :guild_id,
    :channel_id,
    :session_id,
    :token,
    :endpoint,
    connected: false,
    streaming: false,
    speaking: false,
    audio_queue: :queue.new(),
    connection_pid: nil
  ]

  @doc """
  Creates a new voice channel struct.
  """
  def new(guild_id, channel_id) do
    %__MODULE__{
      guild_id: guild_id,
      channel_id: channel_id
    }
  end

  @doc """
  Joins a voice channel by establishing a voice connection.
  """
  def join(%__MODULE__{} = channel, guild_id, channel_id) do
    case Connection.establish(guild_id, channel_id) do
      {:ok, connection_info} ->
        updated_channel = %{
          channel |
          guild_id: guild_id,
          channel_id: channel_id,
          session_id: connection_info.session_id,
          token: connection_info.token,
          endpoint: connection_info.endpoint,
          connected: true,
          connection_pid: connection_info.pid
        }
        {:ok, updated_channel}

      {:error, reason} ->
        Logger.error("Failed to join voice channel: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Leaves the current voice channel.
  """
  def leave(%__MODULE__{connection_pid: nil} = channel) do
    {:ok, %{channel | connected: false}}
  end

  def leave(%__MODULE__{connection_pid: pid} = channel) when is_pid(pid) do
    Connection.close(pid)
    {:ok, %{channel | connected: false, streaming: false, speaking: false, connection_pid: nil}}
  end

  @doc """
  Starts audio streaming in the voice channel.
  """
  def start_streaming(%__MODULE__{connected: true} = channel) do
    case Connection.start_streaming(channel.connection_pid) do
      :ok ->
        {:ok, %{channel | streaming: true}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def start_streaming(%__MODULE__{connected: false}) do
    {:error, :not_connected}
  end

  @doc """
  Stops audio streaming in the voice channel.
  """
  def stop_streaming(%__MODULE__{connected: true, streaming: true} = channel) do
    Connection.stop_streaming(channel.connection_pid)
    {:ok, %{channel | streaming: false, speaking: false}}
  end

  def stop_streaming(%__MODULE__{}) do
    {:error, :not_streaming}
  end

  @doc """
  Sets the speaking state in the voice channel.
  """
  def set_speaking(%__MODULE__{connected: true} = channel, speaking) when is_boolean(speaking) do
    Connection.set_speaking(channel.connection_pid, speaking)
    {:ok, %{channel | speaking: speaking}}
  end

  def set_speaking(%__MODULE__{}, _speaking) do
    {:error, :not_connected}
  end

  @doc """
  Queues audio data for playback.
  """
  def queue_audio(%__MODULE__{audio_queue: queue} = channel, audio_data) when is_binary(audio_data) do
    new_queue = :queue.in(audio_data, queue)
    {:ok, %{channel | audio_queue: new_queue}}
  end

  @doc """
  Dequeues the next audio data for playback.
  """
  def dequeue_audio(%__MODULE__{audio_queue: queue} = channel) do
    case :queue.out(queue) do
      {{:value, audio_data}, new_queue} ->
        {audio_data, %{channel | audio_queue: new_queue}}

      {:empty, _} ->
        {nil, channel}
    end
  end

  @doc """
  Returns the number of queued audio items.
  """
  def queue_size(%__MODULE__{audio_queue: queue}) do
    :queue.len(queue)
  end

  @doc """
  Clears the audio queue.
  """
  def clear_queue(%__MODULE__{} = channel) do
    %{channel | audio_queue: :queue.new()}
  end
end