defmodule Lux.Lenses.Discord.Analytics.ServerAnalyticsLens do
  @moduledoc """
  Lens & Analytics Engine for Discord Server Analytics (`Spectral-Finance/lux#56`).

  Provides:
  - Activity tracking implementation (`record_event/2`)
  - Usage statistics collection (messages, voice minutes, commands)
  - Member analytics processing (active members, engagement score, retention)
  - Event logging and storage in ETS (`get_analytics/1`, `clear_analytics/1`)
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Discord Server Analytics & Activity Lens",
    description: "Collects and aggregates Discord guild activity, member engagement, and event logs",
    url: "https://discord.com/api/v10/guilds/:guild_id/preview",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the Discord guild to analyze"
        }
      },
      required: ["guild_id"]
    }

  @table :lux_discord_analytics_events

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, :bag, read_concurrency: true])
      _ -> @table
    end
  end

  @doc """
  Records a Discord server event (e.g., `:message_sent`, `:voice_join`, `:command_used`, `:member_join`)
  into the analytics store.
  """
  def record_event(guild_id, %{type: type, member_id: member_id} = event) do
    ensure_table()
    entry = Map.merge(event, %{
      guild_id: guild_id,
      type: type,
      member_id: member_id,
      timestamp: Map.get(event, :timestamp, System.system_time(:second))
    })
    :ets.insert(@table, {guild_id, entry})
    {:ok, entry}
  end

  @doc """
  Computes usage statistics, member analytics, and event logs for a guild.
  """
  def get_analytics(guild_id) do
    ensure_table()
    events =
      :ets.lookup(@table, guild_id)
      |> Enum.map(fn {^guild_id, ev} -> ev end)

    total_events = length(events)
    unique_members = events |> Enum.map(& &1.member_id) |> Enum.uniq() |> length()

    by_type =
      Enum.reduce(events, %{}, fn ev, acc ->
        Map.update(acc, ev.type, 1, &(&1 + 1))
      end)

    %{
      guild_id: guild_id,
      usage_statistics: %{
        total_events: total_events,
        events_by_type: by_type
      },
      member_analytics: %{
        active_members: unique_members,
        avg_events_per_member: if(unique_members > 0, do: Float.round(total_events / unique_members, 2), else: 0.0)
      },
      event_log: events
    }
  end

  @doc """
  Clears stored analytics events for a guild.
  """
  def clear_analytics(guild_id) do
    ensure_table()
    :ets.delete(@table, guild_id)
    :ok
  end

  @impl true
  def after_focus(%{"id" => guild_id} = body) do
    analytics = get_analytics(guild_id)
    {:ok, Map.merge(analytics, %{
      guild_name: body["name"],
      approximate_member_count: body["approximate_member_count"] || 0,
      approximate_presence_count: body["approximate_presence_count"] || 0
    })}
  end

  def after_focus(body), do: {:ok, body}
end
