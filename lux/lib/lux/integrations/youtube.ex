defmodule Lux.Integrations.YouTube do
  @moduledoc """
  Common settings and functions for YouTube Data API v3 integration.

  Supports two authentication modes:
  - **API Key** — for read-only public data (channels, videos, search)
  - **OAuth2 Bearer Token** — for user-specific and write operations
    (upload video, manage broadcasts, send chat messages)

  ## Configuration

  Configure in your application config:

      config :lux, :api_keys,
        youtube_api_key: "your_api_key",
        youtube_oauth_token: "your_oauth2_bearer_token"

  Get credentials at: https://console.developers.google.com/

  ## Rate Limits

  - YouTube Data API v3 uses a quota unit system (10,000 units/day by default)
  - Read operations: 1-100 units each
  - Write operations: 50-1600 units each
  - Live streaming operations: 100-1600 units each
  """

  @base_url "https://www.googleapis.com/youtube/v3"
  @upload_url "https://www.googleapis.com/upload/youtube/v3"

  @doc "Returns the YouTube Data API v3 base URL."
  def base_url, do: @base_url

  @doc "Returns the YouTube upload API URL."
  def upload_url, do: @upload_url

  @doc "Common JSON content-type header for YouTube API calls."
  def headers, do: [{"Content-Type", "application/json"}, {"Accept", "application/json"}]

  @doc """
  API key auth settings for read-only public endpoints.
  Adds `key` query parameter.
  """
  def api_key_auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_api_key/1
    }
  end

  @doc """
  OAuth2 Bearer token auth for user-specific and write endpoints.
  """
  def oauth_auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_oauth_token/1
    }
  end

  @doc "Adds YouTube API key as query parameter if configured."
  @spec add_api_key(Lux.Lens.t()) :: Lux.Lens.t()
  def add_api_key(%Lux.Lens{} = lens) do
    case Application.get_env(:lux, :api_keys)[:youtube_api_key] do
      nil -> lens
      key -> %{lens | params: Map.put(lens.params || %{}, "key", key)}
    end
  end

  @doc "Adds OAuth2 Bearer token header if configured."
  @spec add_oauth_token(Lux.Lens.t()) :: Lux.Lens.t()
  def add_oauth_token(%Lux.Lens{} = lens) do
    case Application.get_env(:lux, :api_keys)[:youtube_oauth_token] do
      nil -> lens
      token -> %{lens | headers: lens.headers ++ [{"Authorization", "Bearer #{token}"}]}
    end
  end
end
