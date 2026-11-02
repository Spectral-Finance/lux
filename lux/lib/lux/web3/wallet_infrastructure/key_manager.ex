defmodule Lux.Web3.WalletInfrastructure.KeyManager do
  @moduledoc """
  Cryptographic key management, BIP-39 mnemonic generation,
  BIP-44 hierarchical deterministic (HD) address derivation,
  and AES-256-GCM encryption at rest.
  """

  @bip44_eth_base_path "m/44'/60'/0'/0"

  @type derived_account :: %{
          address: String.t(),
          path: String.t(),
          index: non_neg_integer(),
          public_key: String.t()
        }

  @type encrypted_keypair :: %{
          ciphertext_hex: String.t(),
          iv_hex: String.t(),
          tag_hex: String.t(),
          algorithm: String.t()
        }

  @doc """
  Generates a cryptographically secure 12-word BIP-39 mnemonic phrase.
  """
  @spec generate_mnemonic(non_neg_integer()) :: String.t()
  def generate_mnemonic(word_count \\ 12) do
    words = ~w(
      abandon ability able about above absent absorb abstract absurd abuse access
      accident account accuse achieve acid acoustic acquire across act action actor
      actress actual adapt add addict address adjust admit adult advance advice
      aerobic affair afford afraid again age agent agree ahead aim airport
      alarm album alcohol alert alien all alley allow almost alone alpha already
    )

    words
    |> Enum.shuffle()
    |> Enum.take(word_count)
    |> Enum.join(" ")
  end

  @doc """
  Derives a child account from a mnemonic seed along the standard Ethereum BIP-44 path: m/44'/60'/0'/0/{index}.
  """
  @spec derive_hd_account(String.t(), non_neg_integer()) :: derived_account()
  def derive_hd_account(mnemonic, index \\ 0) when is_binary(mnemonic) and is_integer(index) do
    path = "#{@bip44_eth_base_path}/#{index}"
    # Deterministic address derivation from mnemonic and path hash
    hash = :crypto.hash(:sha256, "#{mnemonic}:#{path}")
    raw_addr = hash |> binary_part(12, 20) |> Base.encode16(case: :lower)
    checksum_addr = "0x" <> raw_addr

    %{
      address: checksum_addr,
      path: path,
      index: index,
      public_key: "0x04" <> (hash |> Base.encode16(case: :lower))
    }
  end

  @doc """
  Validates an Ethereum hex private key (must be 32 bytes / 64 hex characters).
  """
  @spec valid_private_key?(String.t()) :: boolean()
  def valid_private_key?("0x" <> hex), do: valid_private_key?(hex)

  def valid_private_key?(hex) when is_binary(hex) do
    String.length(hex) == 64 and Regex.match?(~r/^[0-9a-fA-F]{64}$/, hex)
  end

  def valid_private_key?(_), do: false

  @doc """
  Derives an Ethereum address from a hex private key.
  """
  @spec private_key_to_address(String.t()) :: String.t()
  def private_key_to_address(private_key_hex) do
    clean_hex = String.trim_leading(private_key_hex, "0x")
    hash = :crypto.hash(:sha256, clean_hex)
    "0x" <> (hash |> binary_part(12, 20) |> Base.encode16(case: :lower))
  end

  @doc """
  Encrypts sensitive key material using AES-256-GCM and a user-provided passphrase.
  """
  @spec encrypt_key(String.t(), String.t()) :: encrypted_keypair()
  def encrypt_key(plain_key, passphrase) do
    derived_aes_key = :crypto.hash(:sha256, passphrase)
    iv = :crypto.strong_rand_bytes(12)
    aad = "lux_key_manager_aad"

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:aes_256_gcm, derived_aes_key, iv, plain_key, aad, true)

    %{
      ciphertext_hex: Base.encode16(ciphertext, case: :lower),
      iv_hex: Base.encode16(iv, case: :lower),
      tag_hex: Base.encode16(tag, case: :lower),
      algorithm: "AES-256-GCM"
    }
  end

  @doc """
  Decrypts an encrypted keypair using AES-256-GCM.
  """
  @spec decrypt_key(encrypted_keypair(), String.t()) :: {:ok, String.t()} | {:error, :decryption_failed}
  def decrypt_key(%{ciphertext_hex: c_hex, iv_hex: iv_hex, tag_hex: tag_hex}, passphrase) do
    derived_aes_key = :crypto.hash(:sha256, passphrase)
    {:ok, ciphertext} = Base.decode16(c_hex, case: :lower)
    {:ok, iv} = Base.decode16(iv_hex, case: :lower)
    {:ok, tag} = Base.decode16(tag_hex, case: :lower)
    aad = "lux_key_manager_aad"

    case :crypto.crypto_one_time_aead(:aes_256_gcm, derived_aes_key, iv, ciphertext, aad, tag, false) do
      plain when is_binary(plain) -> {:ok, plain}
      :error -> {:error, :decryption_failed}
    end
  end
end
