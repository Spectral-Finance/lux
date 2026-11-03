defmodule Lux.Integrations.Telegram.CoreClient do
  @moduledoc """
  Telegram Bot API Core Integration for message formatting, inline keyboards, and update handling (#62).
  """

  def build_send_message_payload(chat_id, text, opts \\ [])
      when (is_integer(chat_id) or is_binary(chat_id)) and is_binary(text) do
    trimmed = String.trim(text)

    if trimmed == "" do
      {:error, :empty_message}
    else
      payload = %{
        chat_id: chat_id,
        text: trimmed,
        parse_mode: Keyword.get(opts, :parse_mode, "MarkdownV2"),
        disable_web_page_preview: Keyword.get(opts, :disable_preview, false)
      }

      {:ok, payload}
    end
  end
end
