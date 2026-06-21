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
  Used with Req and Lux.Lens.
  """
  @spec add_auth_header(Lux.Lens.t() | map()) :: Lux.Lens.t() | map()
  def add_auth_header(%Lux.Lens{} = lens) do
    token = Lux.Config.telegram_bot_token()
    url = lens.url
    
    updated_url = if String.contains?(url, "/bot/"), do: 
      String.replace(url, "/bot/", "/bot#{token}/"), 
    else: 
      url
      
    %{lens | url: updated_url}
  end

  def add_auth_header(%{request_path: path} = conn) do
    token = Lux.Config.telegram_bot_token()
    
    # Extract and replace bot token placeholder if needed
    updated_path = if String.contains?(path, "/bot/"), do: 
      String.replace(path, "/bot/", "/bot#{token}/"), 
    else: 
      path
      
    %{conn | request_path: updated_path}
  end
end 