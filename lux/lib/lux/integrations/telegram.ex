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
  Adds Telegram bot token to the URL or request path.
  Used with Req or Plug.Conn or Lux.Lens.
  """
  def add_auth_header(%Lux.Lens{url: nil} = lens) do
    %{lens | url: ""}
  end

  def add_auth_header(%Lux.Lens{url: url, params: params} = lens) when is_binary(url) do
    token = fetch_token(params)

    updated_url =
      cond do
        String.contains?(url, "/bot{token}/") -> String.replace(url, "/bot{token}/", "/bot#{token}/")
        String.contains?(url, "/bot/") -> String.replace(url, "/bot/", "/bot#{token}/")
        true -> url
      end

    %{lens | url: updated_url}
  end

  def add_auth_header(%Plug.Conn{request_path: nil} = conn) do
    %{conn | request_path: ""}
  end

  def add_auth_header(%Plug.Conn{request_path: path} = conn) when is_binary(path) do
    token = fetch_token(%{})

    updated_path =
      cond do
        String.contains?(path, "/bot{token}/") -> String.replace(path, "/bot{token}/", "/bot#{token}/")
        String.contains?(path, "/bot/") -> String.replace(path, "/bot/", "/bot#{token}/")
        true -> path
      end

    %{conn | request_path: updated_path}
  end

  @doc """
  Fetches the Telegram Bot Token from options or configuration/environment.
  """
  def fetch_token(opts) when is_map(opts) do
    case Map.get(opts, :token) || Map.get(opts, "token") do
      token when is_binary(token) -> token
      _ -> fallback_token()
    end
  end

  def fetch_token(opts) when is_list(opts) do
    case Keyword.get(opts, :token) do
      token when is_binary(token) -> token
      _ -> fallback_token()
    end
  end

  def fetch_token(_), do: fallback_token()

  defp fallback_token do
    token =
      try do
        Lux.Config.telegram_bot_token()
      rescue
        _ -> nil
      catch
        _ -> nil
      end

    token || System.get_env("TELEGRAM_BOT_TOKEN")
  end
end 