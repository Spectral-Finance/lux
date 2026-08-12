defmodule Lux.Prisms.Discord.Analytics.GetMemberAnalytics do
  @moduledoc """
  A prism for retrieving Discord member analytics.

  Provides member join/leave trends, activity levels, role distribution,
  and engagement metrics.
  """

  use Lux.Prism,
    name: "Get Discord Member Analytics",
    description: "Retrieves member analytics and engagement metrics",
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
          description: "Time period for analytics",
          enum: ["day", "week", "month", "all"],
          default: "week"
        },
        include_roles: %{
          type: :boolean,
          description: "Include role distribution",
          default: true
        }
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether analytics were successfully retrieved"
        },
        guild_id: %{
          type: :string,
          description: "The guild ID"
        },
        period: %{
          type: :string,
          description: "Period queried"
        },
        analytics: %{
          type: :object,
          properties: %{
            total_members: %{type: :integer},
            new_members: %{type: :integer},
            left_members: %{type: :integer},
            net_growth: %{type: :integer},
            active_members: %{type: :integer},
            role_distribution: %{
              type: :array,
              items: %{
                type: :object,
                properties: %{
                  role_id: %{type: :string},
                  role_name: %{type: :string},
                  member_count: %{type: :integer}
                }
              }
            },
            join_timeline: %{
              type: :array,
              items: %{
                type: :object,
                properties: %{
                  date: %{type: :string},
                  joins: %{type: :integer},
                  leaves: %{type: :integer}
                }
              }
            },
            engagement_score: %{type: :number}
          }
        }
      },
      required: ["success"]
    }

  alias Lux.Prisms.Discord.Helpers
  alias Lux.Prisms.Discord.Analytics.TrackActivity
  require Logger

  @doc """
  Retrieves member analytics for a guild.

  Returns {:ok, %{success: true, analytics: ...}} on success.
  Returns {:error, reason} on failure.
  """
  @spec handler(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def handler(params, agent) do
    with {:ok, guild_id} <- Helpers.validate_string(params, "guild_id"),
         {:ok, period} <- Helpers.validate_string(params, "period", "week"),
         {:ok, include_roles} <- Helpers.validate_boolean(params, "include_roles", true) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} retrieving member analytics for guild #{guild_id} (#{period})")

      events = TrackActivity.get_guild_events(guild_id)
      filtered_events = filter_by_period(events, period)

      analytics = compute_member_analytics(filtered_events, include_roles)

      {:ok, %{
        success: true,
        guild_id: guild_id,
        period: period,
        analytics: analytics
      }}
    end
  end

  defp filter_by_period(events, period) do
    cutoff = case period do
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

  defp compute_member_analytics(events, include_roles) do
    joins = Enum.filter(events, fn e -> e.event_type == "member_join" end)
    leaves = Enum.filter(events, fn e -> e.event_type == "member_leave" end)
    bans = Enum.filter(events, fn e -> e.event_type == "member_ban" end)
    unbans = Enum.filter(events, fn e -> e.event_type == "member_unban" end)

    new_members = length(joins)
    left_members = length(leaves) + length(bans)
    net_growth = new_members - left_members
    
    # Active members = unique users who sent messages or joined voice
    active_users = events
      |> Enum.filter(fn e -> e.event_type in ["message", "voice_join", "reaction_add"] end)
      |> Enum.map(&(&1.user_id))
      |> Enum.uniq()
      |> length()

    # Join timeline
    join_timeline = joins
      |> Enum.group_by(fn e -> DateTime.from_iso8601!(e.timestamp) |> DateTime.to_string("YYYY-MM-DD") end)
      |> Enum.map(fn {date, day_joins} ->
        day_leaves = Enum.filter(leaves, fn e -> 
          DateTime.from_iso8601!(e.timestamp) |> DateTime.to_string("YYYY-MM-DD") == date 
        end)
        %{date: date, joins: length(day_joins), leaves: length(day_leaves)}
      end)

    analytics = %{
      total_members: 0,  # Would need guild API to get exact count
      new_members: new_members,
      left_members: left_members,
      net_growth: net_growth,
      active_members: active_users,
      join_timeline: join_timeline,
      engagement_score: if(new_members + left_members > 0, do: active_users / (new_members + left_members), else: 0)
    }

    if include_roles do
      # Role distribution would need guild API
      analytics = Map.put(analytics, :role_distribution, [])
    end

    analytics
  end
end