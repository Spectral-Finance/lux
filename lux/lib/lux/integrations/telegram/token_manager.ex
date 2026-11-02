defmodule Lux.Integrations.Telegram.TokenManager do
  @moduledoc """
  Secure token management system for Telegram Bot API.
  Provides format validation, multi-bot registry, token masking for logs,
  and AES-256-GCM authenticated encryption/decryption at rest.
  """

  @token_regex ~r/^[0-9]{8,12}:[a-zA-Z0-9_-]{35}$/

  @type bot_record :: %{
          bot_id: non_neg_integer(),
          name: String.t(),
          encrypted_token: String.t(),
          created_at: String.t()
        }

  @type registry :: %{String.t() => bot_record()}

  @doc """
  Validates whether a string matches the Telegram Bot API token pattern (`<bot_id>:<secret>`).
  """
  @spec valid_token_format?(String.t()) :: boolean()
  def valid_token_format?(token) when is_binary(token) do
    Regex.match?(@token_regex, token)
  end

  def valid_token_format?(_), do: false

  @doc """
  Extracts the bot user ID from a valid Telegram Bot token.
  """
  @spec extract_bot_id(String.t()) :: {:ok, non_neg_integer()} | {:error, :invalid_token}
  def extract_bot_id(token) when is_binary(token) do
    case String.split(token, ":") do
      [id_str, _secret] ->
        case Integer.parse(id_str) do
          {id, ""} -> {:ok, id}
          _ -> {:error, :invalid_token}
        end

      _ ->
        {:error, :invalid_token}
    end
  end

  def extract_bot_id(_), do: {:error, :invalid_token}

  @doc """
  Masks a Telegram token for safe logging (e.g. `123456789:ABC...XYZ`).
  """
  @spec mask_token(String.t()) :: String.t()
  def mask_token(token) when is_binary(token) do
    case String.split(token, ":") do
      [id, secret] when byte_size(secret) >= 8 ->
        prefix = String.slice(secret, 0, 4)
        suffix = String.slice(secret, -4, 4)
        "#{id}:#{prefix}...#{suffix}"

      _ ->
        "***masked***"
    end
  end

  def mask_token(_), do: "***masked***"

  @doc """
  Encrypts a bot token using AES-256-GCM with PBKDF2 salt derivation.
  """
  @spec encrypt_token(String.t(), String.t()) :: String.t()
  def encrypt_token(token, passphrase) when is_binary(token) and is_binary(passphrase) do
    salt = :crypto.strong_rand_bytes(16)
    key = :crypto.pbkdf2_hmac(:sha256, passphrase, salt, 100_000, 32)
    iv = :crypto.strong_rand_bytes(12)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, token, "telegram_bot_token", true)

    Base.encode64(salt <> iv <> tag <> ciphertext)
  end

  @doc """
  Decrypts an AES-256-GCM encrypted bot token.
  """
  @spec decrypt_token(String.t(), String.t()) :: {:ok, String.t()} | {:error, :decryption_failed}
  def decrypt_token(encoded, passphrase) when is_binary(encoded) and is_binary(passphrase) do
    case Base.decode64(encoded) do
      {:ok, <<salt::binary-size(16), iv::binary-size(12), tag::binary-size(16), ciphertext::binary>>} ->
        key = :crypto.pbkdf2_hmac(:sha256, passphrase, salt, 100_000, 32)

        case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, "telegram_bot_token", tag, false) do
          :error ->
            {:error, :decryption_failed}

          plaintext when is_binary(plaintext) ->
            {:ok, plaintext}
        end

      _ ->
        {:error, :decryption_failed}
    end
  end

  @doc """
  Initializes an empty bot token registry.
  """
  @spec init_registry() :: registry()
  def init_registry, do: %{}

  @doc """
  Registers a bot into the registry with encrypted token.
  """
  @spec register_bot(registry(), String.t(), String.t(), String.t()) ::
          {:ok, registry(), bot_record()} | {:error, term()}
  def register_bot(registry, bot_name, token, passphrase) do
    with {:ok, bot_id} <- extract_bot_id(token) do
      encrypted = encrypt_token(token, passphrase)
      now = DateTime.utc_now() |> DateTime.to_iso8601()

      record = %{
        bot_id: bot_id,
        name: bot_name,
        encrypted_token: encrypted,
        created_at: now
      }

      {:ok, Map.put(registry, bot_name, record), record}
    end
  end

  @doc """
  Retrieves and decrypts a bot token from the registry.
  """
  @spec get_bot_token(registry(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, :not_found | :decryption_failed}
  def get_bot_token(registry, bot_name, passphrase) do
    case Map.get(registry, bot_name) do
      nil ->
        {:error, :not_found}

      %{encrypted_token: encrypted} ->
        decrypt_token(encrypted, passphrase)
    end
  end
end
