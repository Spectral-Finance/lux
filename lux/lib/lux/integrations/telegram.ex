defmodule Lux.Integrations.Telegram do
  @moduledoc """
  Common settings and functions for Telegram Bot API integration.

  ## Configuration

  Add your Telegram bot token to your config:

      config :lux, :api_keys,
        telegram: "YOUR_BOT_TOKEN"

  Or set the environment variable:

      export TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN"

  ## Lenses (Read Operations)

  - `Lux.Lenses.Telegram.Messaging.ReadMessage` - Read a message
  - `Lux.Lenses.Telegram.Messaging.ListUpdates` - List updates (incoming messages)
  - `Lux.Lenses.Telegram.Messaging.GetWebhookInfo` - Get webhook status
  - `Lux.Lenses.Telegram.Media.GetFile` - Get file info

  ## Prisms (Write Operations)

  - `Lux.Prisms.Telegram.Messaging.SendMessage` - Send a message
  - `Lux.Prisms.Telegram.Messaging.EditMessage` - Edit a message
  - `Lux.Prisms.Telegram.Messaging.DeleteMessage` - Delete a message
  - `Lux.Prisms.Telegram.Messaging.SetWebhook` - Set webhook
  - `Lux.Prisms.Telegram.Messaging.DeleteWebhook` - Delete webhook
  - `Lux.Prisms.Telegram.Media.SendPhoto` - Send a photo
  - `Lux.Prisms.Telegram.Media.SendDocument` - Send a document
  - `Lux.Prisms.Telegram.Interactive.SendInlineKeyboard` - Send inline keyboard
  - `Lux.Prisms.Telegram.Interactive.AnswerCallbackQuery` - Answer callback query
  """

  @doc """
  Common request settings for Telegram Bot API calls.
  """
  def request_settings do
    %{
      headers: [{"Content-Type", "application/json"}],
      auth: %{
        type: :custom,
        auth_function: &__MODULE__.add_auth_header/1
      }
    }
  end

  @doc """
  Common headers for Telegram Bot API calls.
  """
  def headers, do: [{"Content-Type", "application/json"}]

  @doc """
  Common auth settings for Telegram Bot API calls.
  """
  def auth, do: %{
    type: :custom,
    auth_function: &__MODULE__.add_auth_header/1
  }

  @doc """
  Adds Telegram bot token to the URL.
  Used with Req.
  """
  @spec add_auth_header(Plug.Conn.t()) :: Plug.Conn.t()
  def add_auth_header(%Plug.Conn{} = conn) do
    token = Lux.Config.telegram_bot_token()
    path = conn.request_path
    
    # Extract and replace bot token placeholder if needed
    updated_path = if String.contains?(path, "/bot/") do
      String.replace(path, "/bot/", "/bot#{token}/")
    else
      path
    end
    
    %{conn | request_path: updated_path}
  end
end
