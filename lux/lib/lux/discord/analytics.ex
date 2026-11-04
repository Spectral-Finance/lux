defmodule Lux.Discord.Analytics do
  @moduledoc """
  Server analytics, activity tracking, usage statistics collection, and event logging
  for Discord servers.
  """

  @type event :: %{
          type: String.t(),
          guild_id: String.t(),
          user_id: String.t() | nil,
          metadata: map(),
          timestamp: integer()
        }

  @doc """
  Logs a Discord telemetry or server event.
  """
  @spec log_event(String.t(), String.t(), String.t() | nil, map()) :: map()
  def log_event(event_type, guild_id, user_id \\ nil, metadata \\ %{}) do
    event = %{
      type: event_type,
      guild_id: guild_id,
      user_id: user_id,
      metadata: metadata,
      timestamp: System.system_time(:second)
    }

    history = Process.get(:lux_discord_analytics_events, [])
    Process.put(:lux_discord_analytics_events, [event | history])
    event
  end

  @doc """
  Computes aggregated server activity statistics.
  """
  @spec get_server_stats(String.t()) :: map()
  def get_server_stats(guild_id) do
    history = Process.get(:lux_discord_analytics_events, [])
    guild_events = Enum.filter(history, &(&1.guild_id == guild_id))

    by_type = Enum.frequencies_by(guild_events, & &1.type)
    unique_users = guild_events |> Enum.map(& &1.user_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    %{
      guild_id: guild_id,
      total_events: length(guild_events),
      events_by_type: by_type,
      active_users_count: length(unique_users),
      last_event_timestamp: (List.first(guild_events) || %{timestamp: nil}).timestamp
    }
  end

  @doc """
  Gathers individual member activity statistics.
  """
  @spec get_member_stats(String.t(), String.t()) :: map()
  def get_member_stats(guild_id, user_id) do
    history = Process.get(:lux_discord_analytics_events, [])

    user_events =
      Enum.filter(history, fn e ->
        e.guild_id == guild_id and e.user_id == user_id
      end)

    %{
      guild_id: guild_id,
      user_id: user_id,
      events_count: length(user_events),
      activity_breakdown: Enum.frequencies_by(user_events, & &1.type)
    }
  end

  @doc """
  Clears recorded analytics events.
  """
  @spec reset!() :: :ok
  def reset! do
    Process.put(:lux_discord_analytics_events, [])
    :ok
  end
end
