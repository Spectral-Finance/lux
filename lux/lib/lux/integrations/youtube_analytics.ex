defmodule Lux.Integrations.YoutubeAnalytics do
  @moduledoc """
  Common settings and functions for YouTube Analytics API integration.

  Provides centralized configuration for YouTube Data API v3 access,
  including OAuth2 token management and API key configuration.
  """

  @doc """
  Common request settings for YouTube API calls.
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
  Common headers for YouTube API calls.
  """
  def headers, do: [{"Content-Type", "application/json"}]

  @doc """
  Adds YouTube API key or OAuth2 authorization header.
  """
  @spec add_auth_header(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth_header(%Lux.Lens{} = lens) do
    token = youtube_oauth_token()
    if token do
      %{lens | headers: lens.headers ++ [{"Authorization", "Bearer #{token}"}]}
    else
      lens
    end
  end

  @spec add_auth_header(Plug.Conn.t()) :: Plug.Conn.t()
  def add_auth_header(%Plug.Conn{} = conn) do
    token = youtube_oauth_token()
    if token do
      Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
    else
      conn
    end
  end

  @doc """
  Returns the YouTube API key from application config.
  """
  def youtube_api_key do
    Application.get_env(:lux, :api_keys)[:youtube]
  end

  @doc """
  Returns the YouTube OAuth2 access token from application config.
  """
  def youtube_oauth_token do
    Application.get_env(:lux, :api_keys)[:youtube_oauth_token]
  end

  @doc """
  Returns the configured YouTube API base URL.
  """
  def base_url, do: "https://www.googleapis.com/youtube/v3"

  @doc """
  Returns the YouTube Analytics API base URL.
  """
  def analytics_url, do: "https://youtubeanalytics.googleapis.com/v2"
end
