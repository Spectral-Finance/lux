defmodule Lux.Integrations.Telegram do
  @moduledoc """
  Common settings and functions for Telegram Bot API integration.
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
  Used with Req or Lux.Lens.
  """
  @spec add_auth_header(Plug.Conn.t() | Lux.Lens.t()) :: Plug.Conn.t() | Lux.Lens.t()
  def add_auth_header(%Plug.Conn{} = conn) do
    token = Lux.Config.telegram_bot_token()
    path = conn.request_path
    
    # Extract and replace bot token placeholder if needed
    updated_path = if String.contains?(path, "/bot/"), do: 
      String.replace(path, "/bot/", "/bot#{token}/"), 
    else: 
      path
      
    %{conn | request_path: updated_path}
  end

  def add_auth_header(%Lux.Lens{} = lens) do
    token = Lux.Config.telegram_bot_token()
    updated_url = if String.contains?(lens.url, ":token"), do:
      String.replace(lens.url, ":token", token),
    else:
      lens.url
      
    %{lens | url: updated_url}
  end
end 