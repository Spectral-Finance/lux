defmodule Lux.Integrations.Twitter do
  @moduledoc """
  Common settings and functions for Twitter/X API v2 integration.

  ## Authentication

  Twitter API v2 supports two authentication methods:
  - **OAuth 2.0 Bearer Token** — For app-only access (read-only endpoints)
  - **OAuth 2.0 User Context** — For user actions (posting, liking, etc.)

  Configure tokens in your application config:

      config :lux, :api_keys,
        twitter_bearer: "your_bearer_token",
        twitter_api_key: "your_api_key",
        twitter_api_secret: "your_api_secret",
        twitter_access_token: "your_access_token",
        twitter_access_secret: "your_access_secret"
  """

  @doc """
  Returns common headers for Twitter API requests.
  """
  def headers, do: [{"Content-Type", "application/json"}]

  @doc """
  Returns auth settings for Twitter API.
  """
  def auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_auth_header/1
    }
  end

  @doc """
  Adds Twitter Bearer token authorization header.
  """
  @spec add_auth_header(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth_header(%Lux.Lens{} = lens) do
    token = Application.get_env(:lux, :api_keys)[:twitter_bearer]
    %{lens | headers: lens.headers ++ [{"Authorization", "Bearer #{token}"}]}
  end

  @spec add_auth_header(Plug.Conn.t()) :: Plug.Conn.t()
  def add_auth_header(%Plug.Conn{} = conn) do
    token = Application.get_env(:lux, :api_keys)[:twitter_bearer]
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
  end

  @doc """
  Returns the configured bearer token.
  """
  def bearer_token do
    Application.get_env(:lux, :api_keys)[:twitter_bearer]
  end
end
