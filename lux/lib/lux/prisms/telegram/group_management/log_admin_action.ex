defmodule Lux.Prisms.Telegram.GroupManagement.LogAdminAction do
  @moduledoc """
  A prism for recording administrative moderation actions and generating audit log payloads.
  """

  use Lux.Prism,
    name: "Log Telegram Admin Action",
    description: "Records an admin moderation event into structured audit log format with optional formatted channel notification",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, description: "Action type: 'ban', 'unban', 'mute', 'warn', 'pin', etc."},
        chat_id: %{type: [:string, :integer], description: "Target chat identifier"},
        actor_id: %{type: :integer, description: "ID of admin or bot executing action"},
        target_id: %{type: :integer, description: "ID of user subjected to action"},
        reason: %{type: :string, description: "Reason for moderation action"},
        metadata: %{type: :object, description: "Additional contextual metadata"}
      },
      required: ["action", "chat_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        action: %{type: :string},
        chat_id: %{type: [:string, :integer]},
        formatted_html: %{type: :string},
        formatted_markdown: %{type: :string}
      },
      required: ["id", "action", "formatted_html"]
    }

  alias Lux.Integrations.Telegram.GroupManagement.AuditLogger

  def handler(params, _agent) when is_map(params) do
    action_atom = String.to_atom(to_string(Map.get(params, :action) || Map.get(params, "action", "moderation")))
    chat_id = Map.get(params, :chat_id) || Map.get(params, "chat_id")
    actor_id = Map.get(params, :actor_id) || Map.get(params, "actor_id")
    target_id = Map.get(params, :target_id) || Map.get(params, "target_id")
    reason = Map.get(params, :reason) || Map.get(params, "reason", "Administrative action")
    metadata = Map.get(params, :metadata) || Map.get(params, "metadata", %{})

    chat_id_int = if is_binary(chat_id), do: String.to_integer(chat_id), else: chat_id

    opts = [
      actor_id: actor_id,
      target_id: target_id,
      reason: reason,
      metadata: metadata
    ]

    entry = AuditLogger.create_entry(action_atom, chat_id_int, opts)

    {:ok,
     %{
       id: entry.id,
       action: to_string(entry.action),
       chat_id: entry.chat_id,
       target_id: entry.target_id,
       actor_id: entry.actor_id,
       formatted_html: AuditLogger.format_log_message(entry, :html),
       formatted_markdown: AuditLogger.format_log_message(entry, :markdown)
     }}
  end

  def handler(_, _), do: {:error, "Invalid parameters"}
end
