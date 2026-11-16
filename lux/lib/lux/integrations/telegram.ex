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
  Adds Telegram bot token to the Lens URL or Plug.Conn request path.
  """
  @spec add_auth_header(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth_header(%Lux.Lens{} = lens) do
    token =
      try do
        Lux.Config.telegram_bot_token()
      rescue
        _ -> System.get_env("TELEGRAM_BOT_TOKEN") || ""
      end

    updated_url =
      if String.contains?(lens.url, "/bot/") do
        String.replace(lens.url, "/bot/", "/bot#{token}/")
      else
        lens.url
      end

    %{lens | url: updated_url}
  end

  @spec add_auth_header(Plug.Conn.t()) :: Plug.Conn.t()
  def add_auth_header(%Plug.Conn{} = conn) do
    token =
      try do
        Lux.Config.telegram_bot_token()
      rescue
        _ -> System.get_env("TELEGRAM_BOT_TOKEN") || ""
      end

    path = conn.request_path
    
    # Extract and replace bot token placeholder if needed
    updated_path = if String.contains?(path, "/bot/"), do: 
      String.replace(path, "/bot/", "/bot#{token}/"), 
    else: 
      path
      
    %{conn | request_path: updated_path}
  end
end 