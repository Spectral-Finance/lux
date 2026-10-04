defmodule Lux.Integrations.Telegram do
  @moduledoc """
  Configuration, request settings, webhook/polling management, and API token utilities
  for Telegram Bot API integration in the Lux Framework.
  """

  @default_endpoint "https://api.telegram.org/bot"

  @doc """
  Returns the Telegram Bot API endpoint URL prefix.
  """
  @spec endpoint() :: String.t()
  def endpoint do
    Application.get_env(:lux, :telegram_api_endpoint, @default_endpoint)
  end

  @doc """
  Retrieves the configured bot token from application environment or environment variable.
  """
  @spec bot_token() :: String.t()
  def bot_token do
    Lux.Config.telegram_bot_token()
  end

  @doc """
  Common request settings for Telegram Bot API calls.
  """
  def request_settings do
    %{
      headers: headers(),
      auth: auth()
    }
  end

  @doc """
  Common headers for Telegram Bot API calls.
  """
  def headers do
    [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]
  end

  @doc """
  Common auth settings for Telegram Bot API calls.
  """
  def auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_auth_header/1
    }
  end

  @doc """
  Adds Telegram bot token to the URL path.
  Used with Req / Plug.Conn.
  """
  @spec add_auth_header(Plug.Conn.t()) :: Plug.Conn.t()
  def add_auth_header(%Plug.Conn{} = conn) do
    token = bot_token()
    path = conn.request_path

    updated_path =
      if String.contains?(path, "/bot/") do
        String.replace(path, "/bot/", "/bot#{token}/")
      else
        path
      end

    %{conn | request_path: updated_path}
  end

  @doc """
  Retrieves webhook settings configuration.
  """
  @spec webhook_config() :: map()
  def webhook_config do
    Application.get_env(:lux, :telegram_webhook, %{
      url: nil,
      max_connections: 40,
      allowed_updates: ["message", "edited_message", "callback_query", "channel_post"],
      drop_pending_updates: false,
      secret_token: nil
    })
  end

  @doc """
  Retrieves long polling configuration.
  """
  @spec polling_config() :: map()
  def polling_config do
    Application.get_env(:lux, :telegram_polling, %{
      timeout: 30,
      limit: 100,
      allowed_updates: ["message", "edited_message", "callback_query", "channel_post"],
      offset: 0
    })
  end
end
