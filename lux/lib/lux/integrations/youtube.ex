defmodule Lux.Integrations.YouTube do
  @moduledoc """
  Common settings and helpers for YouTube Data API v3 integrations.

  YouTube write operations require OAuth2 scopes. Lux only reads an access token
  from application configuration or explicit request options; it never performs
  browser OAuth flows or stores refresh tokens.
  """

  @doc "Common JSON headers for YouTube API calls."
  def headers, do: [{"Content-Type", "application/json"}]

  @doc "OAuth bearer-token auth settings for Lux.Lens modules."
  def auth,
    do: %{
      type: :custom,
      auth_function: &__MODULE__.add_auth_header/1
    }

  @doc "Adds the configured YouTube OAuth2 bearer token to a Lux lens request."
  @spec add_auth_header(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth_header(%Lux.Lens{} = lens) do
    token = Lux.Config.youtube_access_token()
    %{lens | headers: lens.headers ++ [{"Authorization", "Bearer #{token}"}]}
  end
end
