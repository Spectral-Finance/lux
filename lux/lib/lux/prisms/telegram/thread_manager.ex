defmodule Lux.Prisms.Telegram.ThreadManager do
  @moduledoc """
  Manages message threading and reply routing logic.
  """

  def build_reply_payload(chat_id, text, reply_to_id \\ nil, thread_id \\ nil) do
    payload = %{
      chat_id: chat_id,
      text: text,
      parse_mode: "MarkdownV2"
    }

    payload = if reply_to_id, do: Map.put(payload, :reply_to_message_id, reply_to_id), else: payload
    payload = if thread_id, do: Map.put(payload, :message_thread_id, thread_id), else: payload
    
    payload
  end
end
