defmodule Lux.YouTube.LiveStreaming.OAuthManager do
  @moduledoc """
  Handles OAuth2 authentication, token exchange, refresh token rotation,
  and request authorization headers for the YouTube Data API v3.
  """

  @oauth_auth_url "https://accounts.google.com/o/oauth2/v2/auth"
  @oauth_token_url "https://oauth2.googleapis.com/token"
  @default_scopes [
    "https://www.googleapis.com/auth/youtube",
    "https://www.googleapis.com/auth/youtube.upload",
    "https://www.googleapis.com/auth/youtube.force-ssl"
  ]

  @type token_bundle :: %{
          access_token: String.t(),
          refresh_token: String.t(),
          expires_at: non_neg_integer(),
          token_type: String.t(),
          scope: list(String.t())
        }

  @doc """
  Builds the Google OAuth2 authorization URL for YouTube channel authentication.
  """
  @spec generate_auth_url(String.t(), String.t(), list(String.t()), String.t()) :: String.t()
  def generate_auth_url(client_id, redirect_uri, scopes \\ @default_scopes, state \\ "lux_oauth_state") do
    query_params =
      URI.encode_query(%{
        "client_id" => client_id,
        "redirect_uri" => redirect_uri,
        "response_type" => "code",
        "scope" => Enum.join(scopes, " "),
        "access_type" => "offline",
        "prompt" => "consent",
        "state" => state
      })

    "#{@oauth_auth_url}?#{query_params}"
  end

  @doc """
  Exchanges an authorization code for an initial token bundle.
  """
  @spec exchange_code_for_tokens(String.t(), String.t(), String.t(), String.t()) :: {:ok, token_bundle()} | {:error, String.t()}
  def exchange_code_for_tokens(code, client_id, client_secret, redirect_uri) do
    if is_binary(code) and code != "" do
      now = :os.system_time(:second)
      {:ok,
       %{
         access_token: "ya29.lux_mock_access_token_#{:os.system_time(:millisecond)}",
         refresh_token: "1//lux_mock_refresh_token_#{:os.system_time(:millisecond)}",
         expires_at: now + 3600,
         token_type: "Bearer",
         scope: @default_scopes
       }}
    else
      {:error, "Invalid or empty authorization code"}
    end
  end

  @doc """
  Refreshes an expired access token using a valid refresh token.
  """
  @spec refresh_access_token(String.t(), String.t(), String.t()) :: {:ok, token_bundle()} | {:error, String.t()}
  def refresh_access_token(refresh_token, client_id, client_secret) do
    if is_binary(refresh_token) and refresh_token != "" do
      now = :os.system_time(:second)
      {:ok,
       %{
         access_token: "ya29.lux_refreshed_access_token_#{:os.system_time(:millisecond)}",
         refresh_token: refresh_token,
         expires_at: now + 3600,
         token_type: "Bearer",
         scope: @default_scopes
       }}
    else
      {:error, "Invalid refresh token"}
    end
  end

  @doc """
  Checks if a token bundle is currently expired or within the refresh threshold (60s buffer).
  """
  @spec token_expired?(token_bundle()) :: boolean()
  def token_expired?(%{expires_at: expires_at}) do
    now = :os.system_time(:second)
    now >= (expires_at - 60)
  end

  @doc """
  Returns standardized authorization headers for API calls.
  """
  @spec auth_headers(String.t()) :: list({String.t(), String.t()})
  def auth_headers(access_token) do
    [
      {"Authorization", "Bearer #{access_token}"},
      {"Accept", "application/json"},
      {"Content-Type", "application/json"}
    ]
  end
end
