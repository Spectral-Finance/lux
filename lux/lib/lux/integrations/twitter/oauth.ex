defmodule Lux.Integrations.Twitter.OAuth do
  @moduledoc """
  Provides OAuth 2.0 flow helper methods for Twitter API v2.
  Handles URL generation and token exchange (PKCE).
  """

  @auth_url "https://twitter.com/i/oauth2/authorize"
  @token_url "https://api.twitter.com/2/oauth2/token"

  @doc """
  Generates an authorization URL for OAuth 2.0 PKCE flow.
  """
  @spec authorize_url(map()) :: String.t()
  def authorize_url(opts \\ %{}) do
    client_id = opts[:client_id] || Application.get_env(:lux, :api_keys)[:twitter_api_key]
    redirect_uri = opts[:redirect_uri] || "http://localhost:4000/auth/twitter/callback"
    scopes = opts[:scopes] || ["tweet.read", "tweet.write", "users.read", "offline.access"]
    state = opts[:state] || :crypto.strong_rand_bytes(16) |> Base.encode64(padding: false) |> URI.encode_www_form()
    code_challenge = opts[:code_challenge] || "challenge" # In real app, generate S256 challenge

    query = URI.encode_query(%{
      "response_type" => "code",
      "client_id" => client_id,
      "redirect_uri" => redirect_uri,
      "scope" => Enum.join(scopes, " "),
      "state" => state,
      "code_challenge" => code_challenge,
      "code_challenge_method" => "plain"
    })

    "#{@auth_url}?#{query}"
  end

  @doc """
  Exchanges an authorization code for an access token.
  """
  @spec get_token(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def get_token(code, opts \\ %{}) do
    client_id = opts[:client_id] || Application.get_env(:lux, :api_keys)[:twitter_api_key]
    redirect_uri = opts[:redirect_uri] || "http://localhost:4000/auth/twitter/callback"
    code_verifier = opts[:code_verifier] || "challenge" # Must match challenge

    payload = %{
      "grant_type" => "authorization_code",
      "code" => code,
      "client_id" => client_id,
      "redirect_uri" => redirect_uri,
      "code_verifier" => code_verifier
    }

    Req.post!(@token_url, form: payload)
    |> case do
      %{status: 200, body: body} -> {:ok, body}
      %{body: body} -> {:error, body}
    end
  end

  @doc """
  Refreshes an access token using a refresh token.
  """
  @spec refresh_token(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def refresh_token(refresh_token, opts \\ %{}) do
    client_id = opts[:client_id] || Application.get_env(:lux, :api_keys)[:twitter_api_key]

    payload = %{
      "grant_type" => "refresh_token",
      "refresh_token" => refresh_token,
      "client_id" => client_id
    }

    Req.post!(@token_url, form: payload)
    |> case do
      %{status: 200, body: body} -> {:ok, body}
      %{body: body} -> {:error, body}
    end
  end
end
