defmodule Lux.Integrations.Telegram do
  @moduledoc """
  Telegram Bot API configuration and shared utilities.
  """

  @base_url "https://api.telegram.org"

  def base_url, do: @base_url

  def bot_url(token) when is_binary(token), do: "#{@base_url}/bot#{token}"

  def file_url(token, file_path), do: "#{@base_url}/file/bot#{token}/#{file_path}"

  @doc "Validate a bot token format."
  def valid_token?(token) when is_binary(token) do
    Regex.match?(~r/^\d+:[A-Za-z0-9_-]{35,}$/, token)
  end

  def valid_token?(_), do: false

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

    updated_path = if String.contains?(path, "/bot/"),
      do: String.replace(path, "/bot/", "/bot#{token}/"),
      else: path

    %{conn | request_path: updated_path}
  end
end