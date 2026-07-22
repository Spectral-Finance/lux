defmodule Lux.Integrations.Telegram.Moderator do
  @moduledoc """
  Telegram Group and Channel moderation system.
  Provides content filtering, spam protection, and admin action logging.
  """

  require Logger
  alias Lux.Prisms.Telegram.Messages.DeleteMessage
  alias Lux.Prisms.Telegram.Moderation.RestrictChatMember

  @default_spam_keywords [
    "casino", "buy crypto now", "cheap tokens", "make money fast", "free giveaway", "investment double"
  ]

  @doc """
  Moderates an incoming message.

  ## Parameters
    - `chat_id`: The ID of the chat/group.
    - `message`: The raw message map from Telegram update (containing e.g., "message_id", "from", "text").
    - `opts`: Configuration options (e.g., custom spam keywords, moderation actions).
  """
  def moderate_message(chat_id, message, opts \\ []) do
    text = message["text"] || ""
    user = message["from"] || %{}
    user_id = user["id"]
    message_id = message["message_id"]

    spam_keywords = opts[:spam_keywords] || @default_spam_keywords
    
    # Evaluate spam rule
    has_spam = Enum.any?(spam_keywords, fn kw -> 
      String.contains?(String.downcase(text), String.downcase(kw))
    end)

    if has_spam and not is_nil(user_id) and not is_nil(message_id) do
      log_admin_action("SPAM_DETECTED", %{
        chat_id: chat_id,
        user_id: user_id,
        username: user["username"] || "unknown",
        message_id: message_id,
        reason: "spam_detected"
      })

      # 1. Delete message
      delete_result = DeleteMessage.handler(%{
        chat_id: chat_id,
        message_id: message_id
      }, %{name: "ModeratorAgent"})

      # 2. Restrict user (mute them)
      restrict_result = RestrictChatMember.handler(%{
        chat_id: chat_id,
        user_id: user_id,
        permissions: %{
          can_send_messages: false,
          can_send_audios: false,
          can_send_documents: false,
          can_send_photos: false,
          can_send_videos: false,
          can_send_video_notes: false,
          can_send_voice_notes: false,
          can_send_polls: false,
          can_send_other_messages: false
        },
        until_date: System.system_time(:second) + 3600 # Mute for 1 hour
      }, %{name: "ModeratorAgent"})

      log_admin_action("MODERATION_ENFORCED", %{
        chat_id: chat_id,
        user_id: user_id,
        delete_status: elem(delete_result, 0),
        restrict_status: elem(restrict_result, 0)
      })

      {:flagged, %{delete: delete_result, restrict: restrict_result}}
    else
      {:ok, :clean}
    end
  end

  # Internal helper for admin logging system
  defp log_admin_action(action_type, details) do
    Logger.warning("[TELEGRAM_MODERATOR_LOG] ACTION=#{action_type} DETAILS=#{inspect(details)}")
  end
end
