defmodule Lux.Integrations.YouTube do
  @moduledoc """
  YouTube Data API v3 and Live Streaming API configuration.

  ## Configuration

      config :lux, :api_keys,
        youtube_api_key: "your-api-key",
        youtube_client_id: "your-client-id",
        youtube_client_secret: "your-client-secret",
        youtube_refresh_token: "your-refresh-token"
  """

  @base_url "https://www.googleapis.com/youtube/v3"
  @oauth_token_url "https://oauth2.googleapis.com/token"
  @upload_url "https://www.googleapis.com/upload/youtube/v3"

  def base_url, do: @base_url
  def upload_url, do: @upload_url
  def oauth_token_url, do: @oauth_token_url

  def api_key, do: get_key(:youtube_api_key) || ""
  def client_id, do: get_key(:youtube_client_id) || ""
  def client_secret, do: get_key(:youtube_client_secret) || ""
  def refresh_token, do: get_key(:youtube_refresh_token) || ""

  defp get_key(key) do
    (Application.get_env(:lux, :api_keys) || %{})[key]
  end
end
