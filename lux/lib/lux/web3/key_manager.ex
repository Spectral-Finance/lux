defmodule Lux.Web3.KeyManager do
  @moduledoc """
  Handles encryption and decryption of private keys using AES-256-GCM.
  """

  @aad "lux-web3-key-manager"
  @tag_length 16
  @iv_length 12

  @doc """
  Encrypts a plaintext string (e.g. private key) and returns a URL-safe Base64 encoded payload.
  """
  @spec encrypt(String.t()) :: {:ok, String.t()} | {:error, any()}
  def encrypt(plaintext) when is_binary(plaintext) do
    key = get_key()
    iv = :crypto.strong_rand_bytes(@iv_length)

    try do
      case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, @aad, @tag_length, true) do
        {ciphertext, tag} ->
          payload = <<iv::binary-size(@iv_length), tag::binary-size(@tag_length), ciphertext::binary>>
          {:ok, Base.url_encode64(payload)}
        _ ->
          {:error, "Encryption failed"}
      end
    rescue
      e -> {:error, "Encryption exception: #{inspect(e)}"}
    end
  end

  @doc """
  Decrypts a URL-safe Base64 encoded payload back to the plaintext string.
  """
  @spec decrypt(String.t()) :: {:ok, String.t()} | {:error, any()}
  def decrypt(encoded_payload) when is_binary(encoded_payload) do
    case Base.url_decode64(encoded_payload) do
      {:ok, <<iv::binary-size(@iv_length), tag::binary-size(@tag_length), ciphertext::binary>>} ->
        key = get_key()

        try do
          decrypted = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, @aad, tag, false)
          {:ok, decrypted}
        rescue
          _ -> {:error, "Decryption failed (invalid tag, key, or corrupted data)"}
        end

      _ ->
        {:error, "Invalid encrypted payload format"}
    end
  end

  defp get_key do
    master_key = System.get_env("MASTER_ENCRYPTION_KEY") || "dev_master_key_must_be_32_bytes_long_or_more"
    :crypto.hash(:sha256, master_key)
  end
end
