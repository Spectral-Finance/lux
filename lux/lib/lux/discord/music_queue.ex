defmodule Lux.Discord.MusicQueue do
  @moduledoc """
  Music playback queue management for Discord voice channels, supporting
  track enqueuing, skip, pause, resume, shuffle, and playlist state tracking.
  """

  @type track :: %{
          title: String.t(),
          url: String.t(),
          duration_seconds: integer(),
          requested_by: String.t()
        }

  @doc """
  Adds a track to the guild's playback queue.
  """
  @spec add_track(String.t(), track()) :: {:ok, map()}
  def add_track(guild_id, track) do
    state = get_guild_state(guild_id)
    updated_queue = state.queue ++ [track]
    new_state = %{state | queue: updated_queue}
    save_guild_state(guild_id, new_state)
    {:ok, %{action: "add_track", queue_length: length(updated_queue), track: track}}
  end

  @doc """
  Retrieves the current queue and playback status.
  """
  @spec get_queue(String.t()) :: map()
  def get_queue(guild_id) do
    get_guild_state(guild_id)
  end

  @doc """
  Skips the current track and advances to the next track in queue.
  """
  @spec skip(String.t()) :: {:ok, track() | nil}
  def skip(guild_id) do
    state = get_guild_state(guild_id)

    case state.queue do
      [next_track | rest] ->
        new_state = %{state | current_track: next_track, queue: rest, is_playing: true}
        save_guild_state(guild_id, new_state)
        {:ok, next_track}

      [] ->
        new_state = %{state | current_track: nil, is_playing: false}
        save_guild_state(guild_id, new_state)
        {:ok, nil}
    end
  end

  @doc """
  Pauses playback.
  """
  @spec pause(String.t()) :: :ok
  def pause(guild_id) do
    state = get_guild_state(guild_id)
    save_guild_state(guild_id, %{state | is_playing: false})
    :ok
  end

  @doc """
  Resumes playback.
  """
  @spec resume(String.t()) :: :ok
  def resume(guild_id) do
    state = get_guild_state(guild_id)
    save_guild_state(guild_id, %{state | is_playing: true})
    :ok
  end

  @doc """
  Shuffles the queued tracks.
  """
  @spec shuffle(String.t()) :: :ok
  def shuffle(guild_id) do
    state = get_guild_state(guild_id)
    shuffled = Enum.shuffle(state.queue)
    save_guild_state(guild_id, %{state | queue: shuffled})
    :ok
  end

  @doc """
  Clears the entire playback queue.
  """
  @spec clear(String.t()) :: :ok
  def clear(guild_id) do
    save_guild_state(guild_id, default_state())
    :ok
  end

  defp get_guild_state(guild_id) do
    queues = Process.get(:lux_discord_music_queues, %{})
    Map.get(queues, guild_id, default_state())
  end

  defp save_guild_state(guild_id, state) do
    queues = Process.get(:lux_discord_music_queues, %{})
    Process.put(:lux_discord_music_queues, Map.put(queues, guild_id, state))
  end

  defp default_state do
    %{
      current_track: nil,
      queue: [],
      is_playing: false,
      loop_mode: :off
    }
  end
end
