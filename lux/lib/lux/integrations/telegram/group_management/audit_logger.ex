defmodule Lux.Integrations.Telegram.GroupManagement.AuditLogger do
  @moduledoc """
  Audit logging system for administrative and moderation actions in Telegram groups.
  Records events, generates formatted notifications for admin log channels,
  and provides filtering queries.
  """

  @type audit_entry :: %{
          id: String.t(),
          action: atom(),
          actor_id: integer() | nil,
          target_id: integer() | nil,
          chat_id: integer(),
          reason: String.t() | nil,
          timestamp: DateTime.t(),
          metadata: map()
        }

  @doc """
  Creates a structured audit log entry.
  """
  @spec create_entry(atom(), integer(), keyword()) :: audit_entry()
  def create_entry(action, chat_id, opts \\ []) when is_atom(action) and is_integer(chat_id) do
    actor_id = Keyword.get(opts, :actor_id)
    target_id = Keyword.get(opts, :target_id)
    reason = Keyword.get(opts, :reason, "No reason specified")
    metadata = Keyword.get(opts, :metadata, %{})
    now = DateTime.utc_now()
    rand_suffix = :rand.uniform(999_999)

    %{
      id: "audit_#{DateTime.to_unix(now)}_#{rand_suffix}",
      action: action,
      actor_id: actor_id,
      target_id: target_id,
      chat_id: chat_id,
      reason: reason,
      timestamp: now,
      metadata: metadata
    }
  end

  @doc """
  Formats an audit log entry for sending to a designated Telegram admin channel or topic.
  """
  @spec format_log_message(audit_entry(), atom()) :: String.t()
  def format_log_message(entry, format \\ :html) do
    icon = action_icon(entry.action)
    action_str = String.upcase(to_string(entry.action))
    iso_time = Calendar.strftime(entry.timestamp, "%Y-%m-%d %H:%M:%S UTC")

    case format do
      :html ->
        """
        #{icon} <b>[AUDIT LOG - #{action_str}]</b>
        <b>Chat ID:</b> <code>#{entry.chat_id}</code>
        <b>Target ID:</b> <code>#{entry.target_id || "N/A"}</code>
        <b>Actor ID:</b> <code>#{entry.actor_id || "Bot"}</code>
        <b>Reason:</b> #{entry.reason}
        <b>Timestamp:</b> <code>#{iso_time}</code>
        """
        |> String.trim()

      :markdown ->
        """
        #{icon} *[AUDIT LOG - #{action_str}]*
        *Chat ID:* `#{entry.chat_id}`
        *Target ID:* `#{entry.target_id || "N/A"}`
        *Actor ID:* `#{entry.actor_id || "Bot"}`
        *Reason:* #{entry.reason}
        *Timestamp:* `#{iso_time}`
        """
        |> String.trim()
    end
  end

  @doc """
  Filters a list of audit entries by criteria.
  """
  @spec filter_entries(list(audit_entry()), map()) :: list(audit_entry())
  def filter_entries(entries, criteria) when is_list(entries) and is_map(criteria) do
    Enum.filter(entries, fn entry ->
      matches_action?(entry, criteria[:action]) and
        matches_actor?(entry, criteria[:actor_id]) and
        matches_target?(entry, criteria[:target_id]) and
        matches_chat?(entry, criteria[:chat_id])
    end)
  end

  defp action_icon(:ban), do: "🔨"
  defp action_icon(:unban), do: "🔓"
  defp action_icon(:mute), do: "🔇"
  defp action_icon(:warn), do: "⚠️"
  defp action_icon(:promote), do: "⭐"
  defp action_icon(:demote), do: "⬇️"
  defp action_icon(:pin), do: "📌"
  defp action_icon(:unpin), do: "📍"
  defp action_icon(:settings_change), do: "⚙️"
  defp action_icon(_), do: "🛡️"

  defp matches_action?(_entry, nil), do: true
  defp matches_action?(entry, act), do: entry.action == act

  defp matches_actor?(_entry, nil), do: true
  defp matches_actor?(entry, actor), do: entry.actor_id == actor

  defp matches_target?(_entry, nil), do: true
  defp matches_target?(entry, target), do: entry.target_id == target

  defp matches_chat?(_entry, nil), do: true
  defp matches_chat?(entry, chat), do: entry.chat_id == chat
end
