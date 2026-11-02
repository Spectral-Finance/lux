defmodule Lux.Integrations.Telegram.Analytics.EngagementTracker do
  @moduledoc """
  Tracks user engagement metrics, unique active users, cohort retention,
  and generates activity leaderboards for users and communities.
  """

  @doc """
  Computes engagement metrics across events.
  """
  @spec analyze(list(map())) :: map()
  def analyze(events) when is_list(events) do
    user_events = Enum.reject(events, &is_nil(&1.user_id))

    user_frequencies =
      user_events
      |> Enum.frequencies_by(& &1.user_id)

    chat_frequencies =
      user_events
      |> Enum.reject(&is_nil(&1.chat_id))
      |> Enum.frequencies_by(& &1.chat_id)

    unique_users = Map.keys(user_frequencies)
    total_unique_users = length(unique_users)

    top_users =
      user_frequencies
      |> Enum.sort_by(fn {_uid, count} -> -count end)
      |> Enum.take(10)
      |> Enum.map(fn {uid, count} -> %{user_id: uid, action_count: count} end)

    top_chats =
      chat_frequencies
      |> Enum.sort_by(fn {_cid, count} -> -count end)
      |> Enum.take(10)
      |> Enum.map(fn {cid, count} -> %{chat_id: cid, message_count: count} end)

    avg_actions_per_user =
      if total_unique_users > 0 do
        Float.round(length(user_events) / total_unique_users, 2)
      else
        0.0
      end

    %{
      total_interactions: length(user_events),
      unique_active_users: total_unique_users,
      average_actions_per_user: avg_actions_per_user,
      top_active_users: top_users,
      top_active_chats: top_chats
    }
  end
end
