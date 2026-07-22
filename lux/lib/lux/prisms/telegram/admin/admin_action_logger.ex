defmodule Lux.Prisms.Telegram.Admin.AdminActionLogger do
  @moduledoc """
  A prism to record and log administrative and moderation actions in Telegram chats.
  Provides structured logging and audit records for admin activities.
  """

  use Lux.Prism,
    name: "Telegram Admin Action Logger",
    description: "Logs administrative and moderation actions in Telegram chats for audit trails",
    input_schema: %{
      type: :object,
      properties: %{
        action_type: %{
          type: :string,
          description: "Type of admin action (e.g., BAN_USER, RESTRICT_USER, SET_TITLE, PIN_MESSAGE)"
        },
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat"
        },
        target_user_id: %{
          type: :integer,
          description: "Target user ID associated with the action, if applicable"
        },
        admin_id: %{
          type: [:string, :integer],
          description: "Admin or agent ID performing the action"
        },
        details: %{
          type: :object,
          description: "Additional contextual details map for the logged action"
        }
      },
      required: ["action_type", "chat_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        logged: %{
          type: :boolean,
          description: "Whether the action was successfully logged"
        },
        log_entry: %{
          type: :object,
          description: "The formatted log entry object"
        }
      },
      required: ["logged", "log_entry"]
    }

  require Logger

  def handler(params, agent) do
    with {:ok, action_type} <- fetch_param(params, :action_type),
         {:ok, chat_id} <- fetch_param(params, :chat_id) do
      admin_id = fetch_optional(params, :admin_id) || agent[:name] || "system"
      target_user_id = fetch_optional(params, :target_user_id)
      details = fetch_optional(params, :details) || %{}

      timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

      log_entry = %{
        timestamp: timestamp,
        action_type: action_type,
        chat_id: chat_id,
        admin_id: admin_id,
        target_user_id: target_user_id,
        details: details
      }

      Logger.info(
        "[TELEGRAM_ADMIN_AUDIT] ACTION=#{action_type} CHAT=#{chat_id} ADMIN=#{admin_id} TARGET=#{inspect(target_user_id)} DETAILS=#{inspect(details)}"
      )

      {:ok, %{logged: true, log_entry: log_entry}}
    end
  end

  defp fetch_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, val} when not is_nil(val) -> {:ok, val}
      _ ->
        case Map.fetch(params, to_string(key)) do
          {:ok, val} when not is_nil(val) -> {:ok, val}
          _ -> {:error, "Missing or invalid #{key}"}
        end
    end
  end

  defp fetch_optional(params, key) do
    case Map.fetch(params, key) do
      {:ok, val} -> val
      :error -> Map.get(params, to_string(key))
    end
  end
end
