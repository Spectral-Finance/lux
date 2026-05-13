defmodule Lux.Integrations.YouTube.OAuth do
  @moduledoc """
  OAuth 2.0 PKCE helpers for YouTube Data API access.
  """

  @authorize_url "https://accounts.google.com/o/oauth2/v2/auth"
  @token_url "https://oauth2.googleapis.com/token"

  @default_scopes [
    "https://www.googleapis.com/auth/youtube",
    "https://www.googleapis.com/auth/youtube.force-ssl",
    "https://www.googleapis.com/auth/youtube.upload"
  ]

  @doc """
  Builds a Google OAuth authorization URL for YouTube access.
  """
  @spec authorization_url(keyword() | map()) :: String.t()
  def authorization_url(opts) do
    code_challenge = option(opts, :code_challenge, nil)

    params = %{
      client_id: required!(opts, :client_id),
      redirect_uri: required!(opts, :redirect_uri),
      response_type: "code",
      access_type: "offline",
      prompt: option(opts, :prompt, "consent"),
      scope: opts |> option(:scopes, @default_scopes) |> Enum.join(" "),
      state: option(opts, :state, nil),
      code_challenge: code_challenge,
      code_challenge_method: if(code_challenge, do: option(opts, :code_challenge_method, "S256"))
    }

    @authorize_url <> "?" <> URI.encode_query(reject_nil(params))
  end

  @doc """
  Creates a token-exchange request body for an authorization code.
  """
  @spec token_request_body(String.t(), keyword() | map()) :: map()
  def token_request_body(code, opts) do
    %{
      client_id: required!(opts, :client_id),
      client_secret: option(opts, :client_secret, nil),
      code: code,
      code_verifier: option(opts, :code_verifier, nil),
      grant_type: "authorization_code",
      redirect_uri: required!(opts, :redirect_uri)
    }
    |> reject_nil()
  end

  @doc """
  Creates a refresh-token request body.
  """
  @spec refresh_request_body(String.t(), keyword() | map()) :: map()
  def refresh_request_body(refresh_token, opts) do
    %{
      client_id: required!(opts, :client_id),
      client_secret: option(opts, :client_secret, nil),
      grant_type: "refresh_token",
      refresh_token: refresh_token
    }
    |> reject_nil()
  end

  @doc """
  Builds an S256 PKCE challenge from a verifier.
  """
  @spec pkce_challenge(String.t()) :: String.t()
  def pkce_challenge(verifier) when is_binary(verifier) do
    :sha256
    |> :crypto.hash(verifier)
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Returns the Google token endpoint used for exchanges.
  """
  @spec token_url() :: String.t()
  def token_url, do: @token_url

  @doc """
  Returns the default YouTube OAuth scopes used by Lux.
  """
  @spec default_scopes() :: [String.t()]
  def default_scopes, do: @default_scopes

  defp required!(opts, key) do
    option(opts, key, nil) || raise ArgumentError, "#{key} is required"
  end

  defp option(opts, key, default), do: opts[key] || default

  defp reject_nil(params) do
    params
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end
end
