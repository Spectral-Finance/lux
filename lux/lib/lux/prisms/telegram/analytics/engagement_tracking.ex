defmodule Lux.Prisms.Telegram.Analytics.EngagementTracking do
  @moduledoc """
  A prism for tracking user engagement metrics from Telegram bot analytics.

  Measures user activity levels including unique user counts, message frequency
  per user, top contributors, and retention rates.

  ## Examples

      iex> EngagementTracking.handler(%{}, %{name: "Agent"})
      {:ok, %{unique_users: 25, active_users: 10, messages_per_user: 6.0, ...}}
  """

  use Lux.Prism,
    name: "Telegram Engagement Tracking",
    description: "Tracks user engagement metrics from Telegram bot analytics data",
    input_schema: %{
      type: :object,
      properties: %{
        time_range: %{
          type: :object,
          description: "Optional time range filter",
          properties: %{
            start: %{type: :string, description: "ISO 8601 start timestamp"},
            end: %{type: :string, description: "ISO 8601 end timestamp"}
          }
        },
        user_id: %{
          type: :integer,
          description: "Optional user ID to filter engagement data"
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        unique_users: %{type: :integer, description: "Number of unique users"},
        active_users: %{type: :integer, description: "Users with 2+ interactions"},
        messages_per_user: %{type: :number, description: "Average messages per user"},
        top_users: %{type: :array, description: "Most active users"},
        retention_rate: %{type: :number, description: "Percentage of returning users"}
      },
      required: ["unique_users", "active_users", "messages_per_user", "top_users", "retention_rate"]
    }

  alias Lux.Integrations.Telegram.Analytics.Collector
  require Logger

  @doc """
  Computes engagement metrics from collected analytics data.
  """
  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} requesting engagement tracking")

    try do
      stats = Collector.get_stats()

      # Combine messages and commands for engagement analysis
      all_events = stats.messages ++ stats.commands
      events = filter_events(all_events, params)

      user_activity = build_user_activity(events)
      unique_users = map_size(user_activity)
      active_users = count_active_users(user_activity)

      result = %{
        unique_users: unique_users,
        active_users: active_users,
        messages_per_user: if(unique_users > 0, do: length(events) / unique_users, else: 0.0),
        top_users: top_users(user_activity, 10),
        retention_rate: if(unique_users > 0, do: Float.round(active_users / unique_users * 100, 2), else: 0.0)
      }

      {:ok, result}
    rescue
      e ->
        Logger.error("Engagement tracking failed: #{inspect(e)}")
        {:error, "Failed to compute engagement metrics: #{Exception.message(e)}"}
    end
  end

  defp filter_events(events, params) do
    events
    |> maybe_filter_time_range(params[:time_range])
    |> maybe_filter_user_id(params[:user_id])
  end

  defp maybe_filter_time_range(events, nil), do: events

  defp maybe_filter_time_range(events, %{start: start_str, end: end_str}) do
    {:ok, start_dt, _} = DateTime.from_iso8601(start_str)
    {:ok, end_dt, _} = DateTime.from_iso8601(end_str)

    Enum.filter(events, fn evt ->
      DateTime.compare(evt.timestamp, start_dt) in [:gt, :eq] and
        DateTime.compare(evt.timestamp, end_dt) in [:lt, :eq]
    end)
  end

  defp maybe_filter_time_range(events, _), do: events

  defp maybe_filter_user_id(events, nil), do: events

  defp maybe_filter_user_id(events, user_id) do
    Enum.filter(events, fn evt ->
      Map.get(evt, :user_id) == user_id || Map.get(evt, :chat_id) == user_id
    end)
  end

  defp build_user_activity(events) do
    Enum.reduce(events, %{}, fn evt, acc ->
      user_id = Map.get(evt, :user_id) || Map.get(evt, :chat_id)

      if user_id do
        Map.update(acc, user_id, 1, &(&1 + 1))
      else
        acc
      end
    end)
  end

  defp count_active_users(user_activity) do
    user_activity
    |> Enum.count(fn {_user_id, count} -> count >= 2 end)
  end

  defp top_users(user_activity, limit) do
    user_activity
    |> Enum.sort_by(fn {_user_id, count} -> count end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {user_id, count} -> %{user_id: user_id, message_count: count} end)
  end
end
