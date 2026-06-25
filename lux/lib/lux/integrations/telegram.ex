defmodule Lux.Integrations.Telegram do
  @moduledoc """
  Telegram Core API Integration ($2,500).

  Provides Bot API configuration, webhook management,
  message formatting, and inline keyboard helpers.

  ## Configuration

      config :lux, Lux.Integrations.Telegram,
        bot_token: System.get_env("TELEGRAM_BOT_TOKEN"),
        webhook_url: System.get_env("TELEGRAM_WEBHOOK_URL")
  """

  @base_url "https://api.telegram.org"

  def bot_token do
    Application.get_env(:lux, __MODULE__, [])[:bot_token] ||
      System.get_env("TELEGRAM_BOT_TOKEN") ||
      raise ArgumentError, "TELEGRAM_BOT_TOKEN not configured"
  end

  def api_url, do: "#{@base_url}/bot#{bot_token()}"
  def headers, do: [{"Content-Type", "application/json"}, {"Accept", "application/json"}]

  # Core endpoints
  def send_message_url,       do: api_url() <> "/sendMessage"
  def send_photo_url,         do: api_url() <> "/sendPhoto"
  def send_document_url,      do: api_url() <> "/sendDocument"
  def edit_message_url,       do: api_url() <> "/editMessageText"
  def delete_message_url,     do: api_url() <> "/deleteMessage"
  def set_webhook_url,        do: api_url() <> "/setWebhook"
  def get_webhook_info_url,   do: api_url() <> "/getWebhookInfo"
  def get_me_url,             do: api_url() <> "/getMe"
  def get_chat_url,           do: api_url() <> "/getChat"
  def get_chat_members_url,   do: api_url() <> "/getChatMemberCount"
  def get_updates_url,        do: api_url() <> "/getUpdates"
  def answer_callback_url,    do: api_url() <> "/answerCallbackQuery"

  @doc "Builds a send_message request body."
  @spec message_body(integer() | String.t(), String.t(), keyword()) :: map()
  def message_body(chat_id, text, opts \\ []) do
    %{chat_id: chat_id, text: text,
      parse_mode: Keyword.get(opts, :parse_mode, "MarkdownV2"),
      disable_notification: Keyword.get(opts, :silent, false)}
    |> maybe_put(:reply_markup, Keyword.get(opts, :keyboard))
    |> maybe_put(:reply_to_message_id, Keyword.get(opts, :reply_to))
  end

  @doc "Builds an inline keyboard markup."
  @spec inline_keyboard(list(list(map()))) :: map()
  def inline_keyboard(rows) do
    %{inline_keyboard: rows}
  end

  @doc "Builds a single inline button."
  @spec button(String.t(), String.t() | nil, String.t() | nil) :: map()
  def button(text, callback_data \\ nil, url \\ nil) do
    %{text: text}
    |> maybe_put(:callback_data, callback_data)
    |> maybe_put(:url, url)
  end

  @doc "Escapes text for MarkdownV2 parse mode."
  @spec escape_markdown(String.t()) :: String.t()
  def escape_markdown(text) do
    ~w([ ] ( ) ~ ` > # + - = | { } . !)
    |> Enum.reduce(text, fn char, acc -> String.replace(acc, char, "\\#{char}") end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)
end
