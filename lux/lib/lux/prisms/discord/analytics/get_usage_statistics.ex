defmodule Lux.Prisms.Discord.Analytics.GetUsageStatistics do
  @moduledoc """
  A prism for retrieving Discord server usage statistics.

  Provides message counts, active users, voice minutes, reaction counts,
  channel activity, and time-series data.
  """

  use Lux.Prism,
    name: "Get Discord Usage Statistics",
    description: "Retrieves comprehensive server usage statistics",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild",
          pattern: "^[0-9]{17,20}$"
        },
        period: %{
          type: :string,
          description: "Time period for statistics",
          enum: ["hour", "day", "week", "month", "all"],
          default: "day"
        },
        metrics: %{
          type: :array,
          description: "Specific metrics to retrieve",
          items: %{
            type: :string,
            enum: ["messages", "reactions", "voice_minutes", "active_users", "channel_activity", "member_growth"]
          },
          default: ["messages", "reactions", "voice_minutes", "active_users"]
        },
        channel_id: %{
          type: :string,
          description: "Filter by specific channel (optional)",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether statistics were successfully retrieved"
        },
        guild_id: %{
          type: :string,
          description: "The guild ID"
        },
        period: %{
          type: :string,
          description: "Period queried"
        },
        statistics: %{
          type: :object,
          properties: %{
            total_messages: %{type: :integer},
            total_reactions: %{type: :integer},
            total_voice_minutes: %{type: :integer},
            active_users: %{type: :integer},
            messages_per_channel: %{
              type: :array,
              items: %{
                type: :object,
                properties: %{
                  channel_id: %{type: :string},
                  channel_name: %{type: :string},
                  message_count: %{type: :integer}
                }
              }
            },
            reactions_breakdown: %{
              type: :array,
              items: %{
                type: :object,
                properties: %{
                  emoji: %{type: :string},
                  count: %{type: :integer}
                }
              }
            },
            hourly_activity: %{
              type: :array,
              items: %{
                type: :object,
                properties: %{
                  hour: %{type: :string},
                  messages: %{type: :integer},
                  active_users: %{type: :integer}
                }
              }
            }
          }
        }
      },
      required: ["success"]
    }

  alias Lux.Prisms.Discord.Helpers
  alias Lux.Prisms.Discord.Analytics.TrackActivity
  require Logger

  @doc """
  Retrieves usage statistics for a guild.

  Returns {:ok, %{success: true, statistics: ...}} on success.
  Returns {:error, reason} on failure.
  """
  @spec handler(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def handler(params, agent) do
    with {:ok, guild_id} <- Helpers.validate_string(params, "guild_id"),
         {:ok, period} <- Helpers.validate_string(params, "period", "day"),
         {:ok, metrics} <- Helpers.validate_string_list(params, "metrics", ["messages", "reactions", "voice_minutes", "active_users"]),
         {:ok, channel_id} <- Helpers.validate_string(params, "channel_id", nil) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} retrieving usage statistics for guild #{guild_id} (#{period})")

      events = TrackActivity.get_guild_events(guild_id)
      filtered_events = filter_by_period(events, period)
      filtered_events = if channel_id, do: Enum.filter(filtered_events, fn e -> e.channel_id == channel_id end), else: filtered_events

      statistics = compute_statistics(filtered_events, metrics)

      {:ok, %{
        success: true,
        guild_id: guild_id,
        period: period,
        statistics: statistics
      }}
    end
  end

  defp filter_by_period(events, period) do
    cutoff = case period do
      "hour" -> DateTime.add(DateTime.utc_now(), -1, :hour)
      "day" -> DateTime.add(DateTime.utc_now(), -1, :day)
      "week" -> DateTime.add(DateTime.utc_now(), -7, :day)
      "month" -> DateTime.add(DateTime.utc_now(), -30, :day)
      "all" -> nil
    end

    if cutoff do
      Enum.filter(events, fn e ->
        DateTime.compare(DateTime.from_iso8601!(e.timestamp), cutoff) >= 0
      end)
    else
      events
    end
  end

  defp compute_statistics(events, metrics) do
    stats = %{
      total_messages: 0,
      total_reactions: 0,
      total_voice_minutes: 0,
      active_users: 0,
      messages_per_channel: [],
      reactions_breakdown: [],
      hourly_activity: []
    }

    if "messages" in metrics do
      messages = Enum.filter(events, fn e -> e.event_type == "message" end)
      stats = Map.put(stats, :total_messages, length(messages))
      
      # Per channel
      channel_stats = messages
        |> Enum.group_by(&(&1.channel_id))
        |> Enum.map(fn {channel_id, msgs} ->
          %{
            channel_id: channel_id,
            channel_name: "channel-#{channel_id}",
            message_count: length(msgs)
          }
        end)
      stats = Map.put(stats, :messages_per_channel, channel_stats)

      # Hourly
      hourly = messages
        |> Enum.group_by(fn e -> DateTime.from_iso8601!(e.timestamp) |> DateTime.to_string("YYYY-MM-DD HH") end)
        |> Enum.map(fn {hour, msgs} ->
          %{
            hour: hour,
            messages: length(msgs),
            active_users: msgs |> Enum.map(&(&1.user_id)) |> Enum.uniq() |> length()
          }
        end)
      stats = Map.put(stats, :hourly_activity, hourly)
    end

    if "reactions" in metrics do
      reactions = Enum.filter(events, fn e -> e.event_type in ["reaction_add", "reaction_remove"] end)
      stats = Map.put(stats, :total_reactions, length(reactions))
      
      reaction_stats = reactions
        |> Enum.group_by(fn e -> e.metadata["emoji"] || "unknown" end)
        |> Enum.map(fn {emoji, reacts} -> %{emoji: emoji, count: length(reacts)} end)
      stats = Map.put(stats, :reactions_breakdown, reaction_stats)
    end

    if "voice_minutes" in metrics do
      voice_events = Enum.filter(events, fn e -> e.event_type in ["voice_join", "voice_leave", "voice_move"] end)
      # Simplified calculation
      stats = Map.put(stats, :total_voice_minutes, length(voice_events) * 5)
    end

    if "active_users" in metrics do
      unique_users = events |> Enum.map(&(&1.user_id)) |> Enum.uniq() |> length()
      stats = Map.put(stats, :active_users, unique_users)
    end

    stats
  end
end