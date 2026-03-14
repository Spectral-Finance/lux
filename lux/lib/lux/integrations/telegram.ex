defmodule Lux.Integrations.Telegram do
  @moduledoc """
  Common settings and functions for Telegram Bot API integration.

  The Telegram Bot API uses a URL-based authentication scheme where the bot token
  is embedded in the URL path: `https://api.telegram.org/bot<token>/methodName`.

  This module provides shared headers, auth configuration, and helper functions
  used by all Telegram lenses and prisms.

  ## Configuration

  Set the bot token in your config:

      config :lux, :api_keys,
        telegram_bot: "your-bot-token"

  Or via the `TELEGRAM_BOT_TOKEN` environment variable.
  """

  @base_url "https://api.telegram.org"

  @doc """
  Returns the base URL for the Telegram Bot API.
  """
  @spec base_url() :: String.t()
  def base_url, do: @base_url

  @doc """
  Common request settings for Telegram Bot API calls.
  """
  def request_settings do
    %{
      headers: [{"Content-Type", "application/json"}],
      auth: %{
        type: :custom,
        auth_function: &__MODULE__.add_auth/1
      }
    }
  end

  @doc """
  Common headers for Telegram Bot API calls.
  """
  def headers, do: [{"Content-Type", "application/json"}]

  @doc """
  Common auth settings for Telegram Bot API calls.

  Uses a custom auth function that injects the bot token into the request URL.
  """
  def auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_auth/1
    }
  end

  @doc """
  Adds Telegram bot token to the lens URL.

  Replaces the `:token` placeholder in the URL with the actual bot token
  from configuration.

  ## Examples

      iex> lens = %Lux.Lens{url: "https://api.telegram.org/bot:token/sendMessage"}
      iex> updated = Telegram.add_auth(lens)
      iex> String.contains?(updated.url, "bot:token")
      false
  """
  @spec add_auth(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth(%Lux.Lens{} = lens) do
    token = Application.get_env(:lux, :api_keys)[:telegram_bot] || ""
    %{lens | url: String.replace(lens.url, ":token", token)}
  end

  @spec add_auth(Plug.Conn.t()) :: Plug.Conn.t()
  def add_auth(%Plug.Conn{} = conn) do
    token = Application.get_env(:lux, :api_keys)[:telegram_bot] || ""
    path = String.replace(conn.request_path, ":token", token)
    %{conn | request_path: path}
  end

  @doc """
  Builds a Telegram Bot API URL for the given method.

  ## Examples

      iex> Telegram.api_url("sendMessage")
      "https://api.telegram.org/bot:token/sendMessage"
  """
  @spec api_url(String.t()) :: String.t()
  def api_url(method) do
    "#{@base_url}/bot:token/#{method}"
  end
end
