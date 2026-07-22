defmodule Lux.Prisms.Telegram.Admin.SpamProtectionFilter do
  @moduledoc """
  A prism to analyze messages for spam content, flag policy violations, and optionally trigger moderation actions.
  """

  use Lux.Prism,
    name: "Telegram Spam Protection Filter",
    description: "Evaluates message content for spam keywords and policy violations with automated action handling",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat"
        },
        text: %{
          type: :string,
          description: "Message content to evaluate"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the message being evaluated"
        },
        user_id: %{
          type: :integer,
          description: "User ID of the sender"
        },
        spam_keywords: %{
          type: :array,
          items: %{type: :string},
          description: "Custom spam keywords list to evaluate against"
        },
        action: %{
          type: :string,
          description: "Action to execute if spam is detected: 'none', 'flag_only', or 'delete_and_mute'"
        }
      },
      required: ["chat_id", "text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        is_spam: %{
          type: :boolean,
          description: "Whether spam was detected in the text"
        },
        matched_keywords: %{
          type: :array,
          items: %{type: :string},
          description: "List of keywords matched in the text"
        },
        action_taken: %{
          type: :string,
          description: "Moderation action taken ('clean', 'flagged', 'deleted_and_muted')"
        }
      },
      required: ["is_spam", "matched_keywords", "action_taken"]
    }

  alias Lux.Prisms.Telegram.Messages.DeleteMessage
  alias Lux.Prisms.Telegram.Admin.RestrictChatMember
  alias Lux.Prisms.Telegram.Admin.AdminActionLogger
  require Logger

  @default_spam_keywords [
    "casino", "buy crypto now", "cheap tokens", "make money fast", "free giveaway", "investment double"
  ]

  def handler(params, agent) do
    with {:ok, chat_id} <- fetch_param(params, :chat_id),
         {:ok, text} <- fetch_param(params, :text) do
      keywords = fetch_optional(params, :spam_keywords) || @default_spam_keywords
      action = fetch_optional(params, :action) || "flag_only"
      message_id = fetch_optional(params, :message_id)
      user_id = fetch_optional(params, :user_id)

      normalized_text = String.downcase(text)

      matched_keywords =
        Enum.filter(keywords, fn kw ->
          String.contains?(normalized_text, String.downcase(kw))
        end)

      is_spam = length(matched_keywords) > 0

      if is_spam do
        AdminActionLogger.handler(%{
          action_type: "SPAM_DETECTED",
          chat_id: chat_id,
          target_user_id: user_id,
          details: %{
            message_id: message_id,
            matched_keywords: matched_keywords
          }
        }, agent)

        action_taken = execute_action(action, chat_id, message_id, user_id, agent)
        {:ok, %{is_spam: true, matched_keywords: matched_keywords, action_taken: action_taken}}
      else
        {:ok, %{is_spam: false, matched_keywords: [], action_taken: "clean"}}
      end
    end
  end

  defp execute_action("delete_and_mute", chat_id, message_id, user_id, agent)
       when not is_nil(message_id) and not is_nil(user_id) do
    DeleteMessage.handler(%{chat_id: chat_id, message_id: message_id}, agent)

    RestrictChatMember.handler(%{
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
      until_date: System.system_time(:second) + 3600
    }, agent)

    "deleted_and_muted"
  end

  defp execute_action("none", _chat_id, _message_id, _user_id, _agent), do: "none"
  defp execute_action(_other, _chat_id, _message_id, _user_id, _agent), do: "flagged"

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
