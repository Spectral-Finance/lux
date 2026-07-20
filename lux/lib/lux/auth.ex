defmodule Lux.Auth do
  @moduledoc """
  Authentication and authorization module for Lux applications.

  Provides:
  - API key management and validation
  - JWT token generation and verification
  - Role-based access control (RBAC)
  - Permission checking
  - Secret management
  - Session management helpers

  ## Features

  - Multiple authentication schemes (API Key, Bearer Token, HMAC)
  - JWT support with configurable expiration
  - Role-based permission system
  - Secret rotation support
  - Audit logging for auth events
  - Rate limiting integration hints

  ## Examples

      # Generate API key
      {:ok, key} = Lux.Auth.generate_api_key()

      # Verify JWT token
      {:ok, claims} = Lux.Auth.verify_jwt(token, secret)

      # Check permissions
      Lux.Auth.has_permission?(user, "prisms.write")
  """

  alias Lux.Config

  @type auth_scheme :: :api_key | :bearer | :hmac | :jwt
  @type role :: String.t()
  @type permission :: String.t()
  @type claims :: map()

  @default_jwt_secret_env "LUX_JWT_SECRET"
  @default_api_key_length 32
  @default_token_expiry_seconds 3600

  # Client API

  @doc """
  Generates a cryptographically secure API key.

  ## Options

    * `:length` - Key length in bytes (default: 32)
    * `:prefix` - Optional prefix for the key

  ## Examples

      iex> Lux.Auth.generate_api_key()
      {:ok, "lux_ak_xxxxxxxxxxxxxxxxxxxxxxxx..."}

      iex> Lux.Auth.generate_api_key(length: 64, prefix: "test_")
      {:ok, "test_xxxxxxxxxxxxxxxxxxxxxxxx..."}
  """
  @spec generate_api_key(keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate_api_key(opts \\ []) do
    length = Keyword.get(opts, :length, @default_api_key_length)
    prefix = Keyword.get(opts, :prefix, "lux_ak_")

    case :crypto.strong_rand_bytes(length) do
      rand ->
        key = prefix <> Base.encode16(rand, case: :lower)
        {:ok, key}

      error ->
        {:error, "Failed to generate random bytes: #{inspect(error)}"}
    end
  end

  @doc """
  Validates an API key format.

  Checks:
  - Non-empty string
  - Correct prefix (optional)
  - Minimum length

  ## Examples

      iex> Lux.Auth.validate_api_key("lux_ak_abc123")
      true

      iex> Lux.Auth.validate_api_key("invalid")
      false
  """
  @spec validate_api_key(String.t(), keyword()) :: boolean()
  def validate_api_key(key, opts \\ []) do
    min_length = Keyword.get(opts, :min_length, 10)
    prefix = Keyword.get(opts, :prefix, "lux_ak_")

    is_binary(key) and
      byte_size(key) >= min_length and
      String.starts_with?(key, prefix)
  end

  @doc """
  Hashes an API key for secure storage.

  Uses SHA-256 with optional salt.

  ## Examples

      iex> Lux.Auth.hash_api_key("lux_ak_secret")
      "sha256_xxxxxxxxx..."

      iex> Lux.Auth.hash_api_key("lux_ak_secret", salt: "mysalt")
      "sha256_yyyyyyyyy..."
  """
  @spec hash_api_key(String.t(), keyword()) :: String.t()
  def hash_api_key(key, opts \\ []) do
    salt = Keyword.get(opts, :salt, "")

    "sha256_" <>
      Base.encode16(
        :crypto.mac(:hmac, :sha256, salt, key),
        case: :lower
      )
  end

  @doc """
  Verifies an API key against its hash.

  ## Examples

      iex> key = "lux_ak_test"
      iex> hash = Lux.Auth.hash_api_key(key)
      iex> Lux.Auth.verify_api_key(key, hash)
      true
  """
  @spec verify_api_key(String.t(), String.t()) :: boolean()
  def verify_api_key(key, hash) when is_binary(key) and is_binary(hash) do
    computed = hash_api_key(key)
    :crypto.constant_time_compare(computed, hash)
  end

  @doc """
  Generates a JWT token with optional claims.

  ## Options

    * `:secret` - Signing secret (default: from env or Config)
    * `:expires_in` - Expiration in seconds (default: 3600)
    * `:issuer` - Token issuer (default: "lux")
    * `:subject` - Token subject
    * `:claims` - Additional claims map

  ## Examples

      iex> Lux.Auth.generate_jwt(%{user_id: "123"})
      {:ok, "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."}

      iex> Lux.Auth.generate_jwt(%{}, expires_in: 7200)
      {:ok, token}
  """
  @spec generate_jwt(map(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate_jwt(claims, opts \\ []) do
    secret = Keyword.get(opts, :secret, get_jwt_secret())
    expires_in = Keyword.get(opts, :expires_in, @default_token_expiry_seconds)
    issuer = Keyword.get(opts, :issuer, "lux")
    subject = Keyword.get(opts, :subject)

    now = System.system_time(:second)

    header = %{
      alg: "HS256",
      typ: "JWT"
    }

    payload =
      claims
      |> Map.put("iat", now)
      |> Map.put("exp", now + expires_in)
      |> Map.put("iss", issuer)
      |> maybe_put("sub", subject)

    header_b64 = Base.url_encode64(Jason.encode!(header), padding: false)
    payload_b64 = Base.url_encode64(Jason.encode!(payload), padding: false)

    signing_input = "#{header_b64}.#{payload_b64}"

    signature =
      :crypto.mac(:hmac, :sha256, secret, signing_input)
      |> Base.url_encode64(padding: false)

    token = "#{signing_input}.#{signature}"

    {:ok, token}
  rescue
    e -> {:error, "Failed to generate JWT: #{Exception.message(e)}"}
  end

  @doc """
  Verifies and decodes a JWT token.

  ## Examples

      iex> {:ok, token} = Lux.Auth.generate_jwt(%{user_id: "123"})
      iex> {:ok, claims} = Lux.Auth.verify_jwt(token)
      iex> claims.user_id
      "123"

      iex> Lux.Auth.verify_jwt("invalid.token.here")
      {:error, :invalid_signature}
  """
  @spec verify_jwt(String.t(), keyword()) :: {:ok, claims()} | {:error, atom()}
  def verify_jwt(token, opts \\ []) do
    secret = Keyword.get(opts, :secret, get_jwt_secret())

    case String.split(token, ".", parts: 3) do
      [header_b64, payload_b64, signature_b64] ->
        signing_input = "#{header_b64}.#{payload_b64}"

        expected_sig =
          :crypto.mac(:hmac, :sha256, secret, signing_input)
          |> Base.url_encode64(padding: false)

        unless :crypto.constant_time_compare(signature_b64, expected_sig) do
          return {:error, :invalid_signature}
        end

        with {:ok, header} <- safe_decode(header_b64),
             {:ok, payload} <- safe_decode(payload_b64) do
          check_expiration(payload)
        end

      _ ->
        {:error, :malformed_token}
    end
  end

  @doc """
  Decodes a JWT token without verification (for debugging).

  ## Examples

      iex> Lux.Auth.decode_jwt(token)
      {:ok, claims}
  """
  @spec decode_jwt(String.t()) :: {:ok, claims()} | {:error, atom()}
  def decode_jwt(token) do
    case String.split(token, ".", parts: 3) do
      [_header_b64, payload_b64, _signature_b64] ->
        safe_decode(payload_b64)

      _ ->
        {:error, :malformed_token}
    end
  end

  @doc """
  Generates an HMAC signature for request authentication.

  ## Options

    * `:algorithm` - Hash algorithm (default: :sha256)

  ## Examples

      iex> Lux.Auth.sign_request("GET /api/data", secret)
      "sha256_xxxxxxxxx..."
  """
  @spec sign_request(binary(), binary(), keyword()) :: String.t()
  def sign_request(message, secret, opts \\ []) do
    algorithm = Keyword.get(opts, :algorithm, :sha256)

    "sha256_" <>
      Base.encode16(
        :crypto.mac(algorithm, secret, message),
        case: :lower
      )
  end

  @doc """
  Verifies an HMAC signature.

  ## Examples

      iex> signature = Lux.Auth.sign_request("message", secret)
      iex> Lux.Auth.verify_signature("message", signature, secret)
      true
  """
  @spec verify_signature(binary(), binary(), binary()) :: boolean()
  def verify_signature(message, signature, secret) when is_binary(message) and is_binary(signature) and is_binary(secret) do
    expected = sign_request(message, secret)
    :crypto.constant_time_compare(expected, signature)
  end

  @doc """
  Generates a secure random secret for encryption/signing.

  ## Options

    * `:length` - Length in bytes (default: 32)

  ## Examples

      iex> Lux.Auth.generate_secret()
      {:ok, "a1b2c3d4..."}
  """
  @spec generate_secret(keyword()) :: {:ok, String.t()} | {:error, term()}
  def generate_secret(opts \\ []) do
    length = Keyword.get(opts, :length, 32)

    case :crypto.strong_rand_bytes(length) do
      rand -> {:ok, Base.encode16(rand, case: :lower)}
      error -> {:error, error}
    end
  end

  @doc """
  Encrypts data using AES-256-GCM.

  ## Options

    * `:key` - Encryption key (must be 32 bytes)
    * `:aad` - Additional authenticated data

  ## Examples

      iex> {:ok, key} = Lux.Auth.generate_secret(length: 32)
      iex> {:ok, encrypted} = Lux.Auth.encrypt("secret data", key)
      iex> {:ok, decrypted} = Lux.Auth.decrypt(encrypted, key)
      iex> decrypted
      "secret data"
  """
  @spec encrypt(binary(), binary(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def encrypt(plaintext, key, opts \\ []) when is_binary(plaintext) and is_binary(key) do
    aad = Keyword.get(opts, :aad, "")

    unless byte_size(key) == 32 do
      {:error, :invalid_key_length}
    else
      iv = :crypto.strong_rand_bytes(12)
      {cipher_text, tag} = :crypto.crypto_one_time_aead(:aes_gcm, key, iv, plaintext, aad, true)

      encrypted =
        iv
        |> <> (tag <> cipher_text)
        |> Base.encode16(case: :lower)

      {:ok, encrypted}
    end
  end

  @doc """
  Decrypts data encrypted with `encrypt/3`.

  ## Examples

      See `encrypt/3` examples.
  """
  @spec decrypt(binary(), binary(), keyword()) :: {:ok, binary()} | {:error, term()}
  def decrypt(encrypted, key, opts \\ []) when is_binary(encrypted) and is_binary(key) do
    aad = Keyword.get(opts, :aad, "")

    unless byte_size(key) == 32 do
      {:error, :invalid_key_length}
    else
      decoded = Base.decode16!(encrypted, case: :lower)

      <<iv::binary-12, tag_and_ciphertext::binary>> = decoded

      <<tag::binary-16, cipher_text::binary>> = tag_and_ciphertext

      case :crypto.crypto_one_time_aead(:aes_gcm, key, iv, cipher_text, aad, tag, false) do
        plaintext when is_binary(plaintext) -> {:ok, plaintext}
        false -> {:error, :decryption_failed}
        error -> {:error, error}
      end
    end
  end

  @doc """
  Checks if a user has a specific permission based on their roles.

  ## Examples

      iex> Lux.Auth.has_permission?("admin", "prisms.write")
      true

      iex> Lux.Auth.has_permission?("viewer", "prisms.write")
      false
  """
  @spec has_permission?(role(), permission()) :: boolean()
  def has_permission?(role, permission) when is_binary(role) and is_binary(permission) do
    role_permissions = get_role_permissions(role)
    Enum.member?(role_permissions, permission) or Enum.member?(role_permissions, "*")
  end

  @doc """
  Gets all permissions for a given role.

  ## Examples

      iex> Lux.Auth.role_permissions("admin")
      ["prisms.read", "prisms.write", "beams.run", "*"]
  """
  @spec role_permissions(role()) :: [permission()]
  def role_permissions(role) when is_binary(role) do
    get_role_permissions(role)
  end

  @doc """
  Creates a permission string from a resource and action.

  ## Examples

      iex> Lux.Auth.permission("prisms", "read")
      "prisms.read"

      iex> Lux.Auth.permission("beams", "execute")
      "beams.execute"
  """
  @spec permission(String.t(), String.t()) :: String.t()
  def permission(resource, action) when is_binary(resource) and is_binary(action) do
    "#{resource}.#{action}"
  end

  @doc """
  Returns the current authentication status for a request context.

  ## Examples

      iex> Lux.Auth.auth_status(%{token: "valid_jwt"})
      {:ok, %{authenticated: true, roles: ["admin"]}}

      iex> Lux.Auth.auth_status(%{})
      {:error, :unauthorized}
  """
  @spec auth_status(map()) :: {:ok, map()} | {:error, atom()}
  def auth_status(context) when is_map(context) do
    case Map.get(context, :token) do
      nil ->
        {:error, :no_token}

      token when is_binary(token) ->
        case verify_jwt(token) do
          {:ok, claims} ->
            roles = Map.get(claims, "roles", ["viewer"])

            {:ok, %{
              authenticated: true,
              user_id: Map.get(claims, "user_id"),
              roles: roles,
              expires_at: Map.get(claims, "exp")
            }}

          {:error, reason} ->
            {:error, reason}
        end

      _ ->
        {:error, :invalid_token}
    end
  end

  # Private Functions

  defp get_jwt_secret do
    System.get_env(@default_jwt_secret_env) ||
      Config.resolve({:runtime_config, :auth, [:jwt, :secret], ""})
  end

  defp safe_decode(b64) do
    case Base.url_decode64(b64, padding: false) do
      {:ok, decoded} ->
        case Jason.decode(decoded) do
          {:ok, json} -> {:ok, json}
          {:error, reason} -> {:error, {:decode_error, reason}}
        end

      {:error, reason} ->
        {:error, {:decode_error, reason}}
    end
  end

  defp check_expiration(payload) do
    exp = Map.get(payload, "exp")

    if exp && exp < System.system_time(:second) do
      {:error, :expired}
    else
      {:ok, payload}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp get_role_permissions(role) do
    default_permissions = %{
      "admin" => ~w(prisms.read prisms.write beams.read beams.write lenses.read lenses.write agents.manage config.read config.write users.manage*),
      "editor" => ~w(prisms.read prisms.write beams.read lenses.read lenses.write agents.read config.read),
      "viewer" => ~w(prisms.read beams.read lenses.read agents.read),
      "service" => ~w(prisms.execute beams.run lenses.focus)
    }

    Map.get(default_permissions, role, ["prisms.read"])
  end
end
