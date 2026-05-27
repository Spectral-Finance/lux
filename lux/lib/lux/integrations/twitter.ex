defmodule Lux.Integrations.Twitter do
  @moduledoc """
  Common settings and functions for Twitter/X API v2 integration.

  Supports OAuth 2.0 with PKCE, tweet management, media upload,
  user profile lookup, and search/timeline queries.

  ## Configuration

  Add to your application config:

      config :lux, :api_keys,
        twitter_bearer_token: "...",
        twitter_client_id: "...",
        twitter_client_secret: "..."

  ## API Version

  This integration targets Twitter API v2 (https://api.twitter.com/2).
  """

  @base_url "https://api.twitter.com/2"
  @upload_url "https://upload.twitter.com/1.1/media/upload.json"
  @oauth2_url "https://twitter.com/i/oauth2"

  @doc """
  Common request settings for Twitter API calls.
  """
  def request_settings do
    %{
      headers: [{"Content-Type", "application/json"}],
      auth: %{
        type: :custom,
        auth_function: &__MODULE__.add_bearer_token/1
      }
    }
  end

  @doc """
  Common headers for Twitter API calls.
  """
  def headers, do: [{"Content-Type", "application/json"}]

  @doc """
  Auth settings for bearer token.
  """
  def auth, do: %{
    type: :custom,
    auth_function: &__MODULE__.add_bearer_token/1
  }

  @doc """
  Adds Twitter Bearer token authorization header for server-side API calls.
  """
  @spec add_bearer_token(Lux.Lens.t()) :: Lux.Lens.t()
  def add_bearer_token(%Lux.Lens{} = lens) do
    token = Application.get_env(:lux, :api_keys)[:twitter_bearer_token]
    %{lens | headers: lens.headers ++ [{"Authorization", "Bearer #{token}"}]}
  end

  @spec add_bearer_token(Plug.Conn.t()) :: Plug.Conn.t()
  def add_bearer_token(%Plug.Conn{} = conn) do
    token = Application.get_env(:lux, :api_keys)[:twitter_bearer_token]
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
  end

  @doc """
  Returns the base URL for Twitter API v2 endpoints.
  """
  def base_url, do: @base_url

  @doc """
  Returns the media upload URL.
  """
  def upload_url, do: @upload_url

  @doc """
  Builds the OAuth 2.0 authorization URL for user-context authentication.
  """
  def oauth2_authorize_url(redirect_uri, state, code_challenge) do
    client_id = Application.get_env(:lux, :api_keys)[:twitter_client_id]

    "#{@oauth2_url}/authorize?" <>
      "response_type=code&" <>
      "client_id=#{client_id}&" <>
      "redirect_uri=#{URI.encode(redirect_uri)}&" <>
      "scope=tweet.read+tweet.write+users.read+offline.access&" <>
      "state=#{state}&" <>
      "code_challenge=#{code_challenge}&" <>
      "code_challenge_method=S256"
  end

  @doc """
  Exchanges an OAuth 2.0 authorization code for access/refresh tokens.
  """
  def exchange_code(code, redirect_uri, code_verifier) do
    client_id = Application.get_env(:lux, :api_keys)[:twitter_client_id]
    client_secret = Application.get_env(:lux, :api_keys)[:twitter_client_secret]

    body = URI.encode_query(%{
      code: code,
      grant_type: "authorization_code",
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_uri,
      code_verifier: code_verifier
    })

    %{method: :post, url: "#{@oauth2_url}/token", body: body, headers: [{"Content-Type", "application/x-www-form-urlencoded"}]}
  end

  @doc """
  Refreshes an OAuth 2.0 access token using a refresh token.
  """
  def refresh_token(refresh_token_value) do
    client_id = Application.get_env(:lux, :api_keys)[:twitter_client_id]
    client_secret = Application.get_env(:lux, :api_keys)[:twitter_client_secret]

    body = URI.encode_query(%{
      refresh_token: refresh_token_value,
      grant_type: "refresh_token",
      client_id: client_id,
      client_secret: client_secret
    })

    %{method: :post, url: "#{@oauth2_url}/token", body: body, headers: [{"Content-Type", "application/x-www-form-urlencoded"}]}
  end
end
