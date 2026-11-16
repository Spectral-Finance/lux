defmodule Lux.Prisms.Telegram.Parser do
  @moduledoc """
  Core Prism for parsing raw Telegram updates into structured internal maps.
  """
  
  def parse(update) when is_map(update) do
    cond do
      Map.has_key?(update, "message") -> parse_message(update["message"])
      Map.has_key?(update, "callback_query") -> parse_callback(update["callback_query"])
      Map.has_key?(update, "edited_message") -> parse_message(update["edited_message"]) |> Map.put(:is_edit, true)
      true -> {:error, :unsupported_update_type}
    end
  end

  defp parse_message(msg) do
    %{
      message_id: msg["message_id"],
      from_id: get_in(msg, ["from", "id"]),
      chat_id: get_in(msg, ["chat", "id"]),
      timestamp: msg["date"],
      text: msg["text"] || msg["caption"] || "",
      reply_to: parse_reply(msg["reply_to_message"]),
      thread_id: msg["message_thread_id"],
      entities: msg["entities"] || [],
      type: detect_type(msg)
    }
  end

  defp parse_callback(cb) do
    %{
      id: cb["id"],
      from_id: get_in(cb, ["from", "id"]),
      data: cb["data"],
      message: parse_message(cb["message"]),
      type: :callback_query
    }
  end

  defp parse_reply(nil), do: nil
  defp parse_reply(msg), do: %{message_id: msg["message_id"], from_id: get_in(msg, ["from", "id"])}

  defp detect_type(msg) do
    cond do
      Map.has_key?(msg, "text") -> :text
      Map.has_key?(msg, "photo") -> :photo
      Map.has_key?(msg, "document") -> :document
      Map.has_key?(msg, "voice") -> :voice
      true -> :unknown
    end
  end
end
