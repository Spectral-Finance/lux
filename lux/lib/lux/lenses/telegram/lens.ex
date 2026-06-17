defmodule Lux.Lenses.Telegram do
  @moduledoc """
  Telegram Bot API lens for Lux.
  """
  alias Lux.Integrations.Telegram.Client

  def send_message(lens, params) do
    with_token(lens, fn token ->
      Client.request(:post, "/sendMessage", token: token, json: params)
    end)
  end

  def edit_message(lens, params) do
    with_token(lens, fn token ->
      Client.request(:post, "/editMessageText", token: token, json: params)
    end)
  end

  def delete_message(lens, params) do
    with_token(lens, fn token ->
      Client.request(:post, "/deleteMessage", token: token, json: params)
    end)
  end

  def copy_message(lens, params) do
    with_token(lens, fn token ->
      Client.request(:post, "/copyMessage", token: token, json: params)
    end)
  end

  def send_photo(lens, params) do
    with_token(lens, fn token ->
      Client.request(:post, "/sendPhoto", token: token, json: params)
    end)
  end

  def send_document(lens, params) do
    with_token(lens, fn token ->
      Client.request(:post, "/sendDocument", token: token, json: params)
    end)
  end

  def send_voice(lens, params) do
    with_token(lens, fn token ->
      Client.request(:post, "/sendVoice", token: token, json: params)
    end)
  end

  def send_inline_keyboard(lens, params) do
    with_token(lens, fn token ->
      Client.request(:post, "/sendMessage", token: token, json: params)
    end)
  end

  def answer_callback_query(lens, params) do
    with_token(lens, fn token ->
      Client.request(:post, "/answerCallbackQuery", token: token, json: params)
    end)
  end

  def set_webhook(lens, params) do
    with_token(lens, fn token ->
      Client.request(:post, "/setWebhook", token: token, json: params)
    end)
  end

  def get_webhook_info(lens) do
    with_token(lens, fn token ->
      Client.request(:get, "/getWebhookInfo", token: token)
    end)
  end

  def get_me(lens) do
    with_token(lens, fn token ->
      Client.request(:get, "/getMe", token: token)
    end)
  end

  def get_updates(lens, params \ %{}) do
    with_token(lens, fn token ->
      Client.request(:post, "/getUpdates", token: token, json: params)
    end)
  end

  defp with_token(lens, fun) do
    token = lens[:token] || Application.get_env(:lux, :telegram, [])[:bot_token]
    if token, do: fun.(token), else: {:error, "Telegram bot token not configured"}
  end
end