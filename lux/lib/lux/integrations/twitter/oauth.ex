defmodule Lux.Integrations.Twitter.OAuth do
  @moduledoc """
  OAuth 2.0 PKCE authentication flow and secure token management for Twitter API v2.
  Supports RFC 7636 PKCE code challenge generation (S256), authorization URL creation,
  authorization code exchange, token refresh, and AES-256-GCM token encryption at rest.
  """

  @auth_url "https://twitter.com/i/oauth2/authorize"
  @token_url "https://api.twitter.com/2/oauth2/token"

  @default_scopes [
    "tweet.read",
    "tweet.write",
    "users.read",
    "offline.access",
    "like.read",
    "like.write"
  ]

  @doc """
  Generates a cryptographically secure PKCE code verifier and code challenge (S256).
  """
  @spec generate_pkce_challenge() :: %{code_verifier: String.t(), code_challenge: String.t()}
  def generate_pkce_challenge do
    verifier =
      :crypto.strong_rand_bytes(64)
      |> Base.url_encode64(padding: false)

    challenge =
      :crypto.hash(:sha256, verifier)
      |> Base.url_encode64(padding: false)

    %{
      code_verifier: verifier,
      code_challenge: challenge
    }
  end

  @doc """
  Constructs the Twitter OAuth 2.0 authorization URL.
  """
  @spec authorization_url(String.t(), String.t(), list(String.t()), String.t(), String.t()) :: String.t()
  def authorization_url(client_id, redirect_uri, scopes \\ @default_scopes, state \\ nil, code_challenge) do
    state = state || (:crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower))
    scope_str = Enum.join(scopes, " ")

    params = %{
      "response_type" => "code",
      "client_id" => client_id,
      "redirect_uri" => redirect_uri,
      "scope" => scope_str,
      "state" => state,
      "code_challenge" => code_challenge,
      "code_challenge_method" => "S256"
    }

    @auth_url <> "?" <> URI.encode_query(params)
  end

  @doc """
  Exchanges an authorization code for an OAuth 2.0 access token and refresh token.
  """
  @spec exchange_code(String.t(), String.t() | nil, String.t(), String.t(), String.t(), map()) ::
          {:ok, map()} | {:error, term()}
  def exchange_code(client_id, client_secret, code, code_verifier, redirect_uri, opts \\ %{}) do
    body_params = %{
      "code" => code,
      "grant_type" => "authorization_code",
      "client_id" => client_id,
      "redirect_uri" => redirect_uri,
      "code_verifier" => code_verifier
    }

    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"}
      | maybe_auth_header(client_id, client_secret)
    ]

    req_opts =
      [
        method: :post,
        url: Map.get(opts, :token_url, @token_url),
        headers: headers,
        form: body_params
      ]
      |> maybe_add_plug(Map.get(opts, :plug))

    req_opts
    |> Req.new()
    |> Req.request()
    |> handle_token_response()
  end

  @doc """
  Refreshes an expired access token using an OAuth 2.0 refresh token.
  """
  @spec refresh_token(String.t(), String.t() | nil, String.t(), map()) ::
          {:ok, map()} | {:error, term()}
  def refresh_token(client_id, client_secret, refresh_token_val, opts \\ %{}) do
    body_params = %{
      "grant_type" => "refresh_token",
      "refresh_token" => refresh_token_val,
      "client_id" => client_id
    }

    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"}
      | maybe_auth_header(client_id, client_secret)
    ]

    req_opts =
      [
        method: :post,
        url: Map.get(opts, :token_url, @token_url),
        headers: headers,
        form: body_params
      ]
      |> maybe_add_plug(Map.get(opts, :plug))

    req_opts
    |> Req.new()
    |> Req.request()
    |> handle_token_response()
  end

  @doc """
  Encrypts token data at rest with AES-256-GCM.
  """
  @spec encrypt_token(map() | String.t(), String.t()) :: String.t()
  def encrypt_token(data, passphrase) do
    serialized = if is_map(data), do: Jason.encode!(data), else: to_string(data)
    salt = :crypto.strong_rand_bytes(16)
    key = :crypto.pbkdf2_hmac(:sha256, passphrase, salt, 100_000, 32)
    iv = :crypto.strong_rand_bytes(12)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, serialized, "twitter_oauth", true)

    Base.encode64(salt <> iv <> tag <> ciphertext)
  end

  @doc """
  Decrypts AES-256-GCM encrypted token data.
  """
  @spec decrypt_token(String.t(), String.t()) :: {:ok, term()} | {:error, :decryption_failed}
  def decrypt_token(encoded, passphrase) do
    case Base.decode64(encoded) do
      {:ok, <<salt::binary-size(16), iv::binary-size(12), tag::binary-size(16), ciphertext::binary>>} ->
        key = :crypto.pbkdf2_hmac(:sha256, passphrase, salt, 100_000, 32)

        case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, "twitter_oauth", tag, false) do
          :error ->
            {:error, :decryption_failed}

          plaintext when is_binary(plaintext) ->
            case Jason.decode(plaintext) do
              {:ok, decoded} -> {:ok, decoded}
              _ -> {:ok, plaintext}
            end
        end

      _ ->
        {:error, :decryption_failed}
    end
  end

  defp maybe_auth_header(_client_id, nil), do: []
  defp maybe_auth_header(_client_id, ""), do: []

  defp maybe_auth_header(client_id, client_secret) do
    auth = Base.encode64("#{client_id}:#{client_secret}")
    [{"Authorization", "Basic #{auth}"}]
  end

  defp handle_token_response({:ok, %{status: 200, body: body}}) when is_map(body) do
    {:ok, body}
  end

  defp handle_token_response({:ok, %{status: status, body: body}}) do
    {:error, {status, body}}
  end

  defp handle_token_response({:error, reason}) do
    {:error, reason}
  end

  defp maybe_add_plug(keyword, nil), do: keyword
  defp maybe_add_plug(keyword, plug), do: Keyword.put(keyword, :plug, plug)
end
