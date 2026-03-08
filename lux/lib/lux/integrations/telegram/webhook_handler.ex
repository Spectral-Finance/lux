defmodule Lux.Integrations.Telegram.WebhookHandler do
  @moduledoc """
  Webhook handler for receiving Telegram Bot API updates.

  Parses incoming updates and dispatches them to registered handlers.
  """

  @doc """
  Parse a raw webhook update payload into a structured update.
  """
  def parse_update(payload) when is_map(payload) do
    update_id = payload["update_id"]

    type = cond do
      payload["message"] -> :message
      payload["edited_message"] -> :edited_message
      payload["callback_query"] -> :callback_query
      payload["inline_query"] -> :inline_query
      payload["chosen_inline_result"] -> :chosen_inline_result
      payload["channel_post"] -> :channel_post
      payload["edited_channel_post"] -> :edited_channel_post
      payload["poll"] -> :poll
      payload["poll_answer"] -> :poll_answer
      payload["my_chat_member"] -> :my_chat_member
      payload["chat_member"] -> :chat_member
      true -> :unknown
    end

    content = payload[to_string(type)] || %{}

    {:ok, %{
      update_id: update_id,
      type: type,
      content: parse_content(type, content),
      raw: payload
    }}
  end

  def parse_update(_), do: {:error, "Invalid update payload"}

  @doc """
  Extract command from a message update.
  Returns `{command, args}` or `:not_command`.
  """
  def extract_command(%{type: :message, content: %{text: text}}) when is_binary(text) do
    case Regex.run(~r/^\/(\w+)(?:@\w+)?\s*(.*)$/s, text) do
      [_, command, args] -> {command, String.trim(args)}
      _ -> :not_command
    end
  end

  def extract_command(_), do: :not_command

  defp parse_content(:message, msg), do: parse_message(msg)
  defp parse_content(:edited_message, msg), do: parse_message(msg)
  defp parse_content(:channel_post, msg), do: parse_message(msg)
  defp parse_content(:edited_channel_post, msg), do: parse_message(msg)

  defp parse_content(:callback_query, query) do
    %{
      id: query["id"],
      from: parse_user(query["from"]),
      message: if(query["message"], do: parse_message(query["message"])),
      data: query["data"],
      chat_instance: query["chat_instance"]
    }
  end

  defp parse_content(:inline_query, query) do
    %{
      id: query["id"],
      from: parse_user(query["from"]),
      query: query["query"],
      offset: query["offset"]
    }
  end

  defp parse_content(_, content), do: content

  defp parse_message(msg) do
    %{
      message_id: msg["message_id"],
      from: parse_user(msg["from"]),
      chat: parse_chat(msg["chat"]),
      date: msg["date"],
      text: msg["text"],
      entities: msg["entities"],
      photo: msg["photo"],
      document: msg["document"],
      voice: msg["voice"],
      video: msg["video"],
      audio: msg["audio"],
      sticker: msg["sticker"],
      reply_to_message: if(msg["reply_to_message"], do: parse_message(msg["reply_to_message"])),
      reply_markup: msg["reply_markup"]
    }
  end

  defp parse_user(nil), do: nil
  defp parse_user(user) do
    %{
      id: user["id"],
      first_name: user["first_name"],
      last_name: user["last_name"],
      username: user["username"],
      is_bot: user["is_bot"]
    }
  end

  defp parse_chat(nil), do: nil
  defp parse_chat(chat) do
    %{
      id: chat["id"],
      type: chat["type"],
      title: chat["title"],
      username: chat["username"],
      first_name: chat["first_name"],
      last_name: chat["last_name"]
    }
  end
end
