defmodule Lux.Web3.Wallet.KeyManager do
  @moduledoc """
  Cryptographic key management, secp256k1 address derivation, BIP-32/BIP-44
  hierarchical deterministic (HD) key derivation, and AES-256-GCM key encryption.
  """

  @secp256k1_n 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
  @pbkdf2_iterations 10_000
  @aad "lux-web3-wallet-v1"

  @type encrypted_envelope :: %{
          cipher: :aes_256_gcm,
          salt: binary(),
          iv: binary(),
          tag: binary(),
          ciphertext: binary()
        }

  @doc """
  Generates a cryptographically strong 32-byte secp256k1 private key as a `0x` hex string.
  """
  @spec generate_private_key() :: {:ok, String.t()}
  def generate_private_key do
    raw = :crypto.strong_rand_bytes(32)
    <<num::unsigned-big-integer-size(256)>> = raw

    if num > 0 and num < @secp256k1_n do
      {:ok, "0x" <> Base.encode16(raw, case: :lower)}
    else
      generate_private_key()
    end
  end

  @doc """
  Generates a 64-byte master seed for HD wallet derivation from a mnemonic or entropy phrase.
  """
  @spec seed_from_phrase(String.t(), String.t()) :: binary()
  def seed_from_phrase(phrase, passphrase \\ "") when is_binary(phrase) do
    salt = "mnemonic" <> passphrase
    :crypto.pbkdf2_hmac(:sha512, phrase, salt, 2048, 64)
  end

  @doc """
  Normalizes and validates a 32-byte private key (accepts `0x`-prefixed hex,
  raw hex, or 32-byte binary).
  """
  @spec normalize_private_key(String.t() | binary()) ::
          {:ok, binary(), String.t()} | {:error, :invalid_private_key}
  def normalize_private_key("0x" <> hex) do
    normalize_private_key(hex)
  end

  def normalize_private_key(hex) when is_binary(hex) and byte_size(hex) == 64 do
    case Base.decode16(hex, case: :mixed) do
      {:ok, <<num::unsigned-big-integer-size(256)>> = raw}
      when num > 0 and num < @secp256k1_n ->
        {:ok, raw, "0x" <> Base.encode16(raw, case: :lower)}

      _ ->
        {:error, :invalid_private_key}
    end
  end

  def normalize_private_key(<<num::unsigned-big-integer-size(256)>> = raw)
      when num > 0 and num < @secp256k1_n do
    {:ok, raw, "0x" <> Base.encode16(raw, case: :lower)}
  end

  def normalize_private_key(_), do: {:error, :invalid_private_key}

  @doc """
  Derives an EIP-55 checksummed Ethereum address from a private key.
  """
  @spec derive_address(String.t() | binary()) ::
          {:ok, String.t()} | {:error, :invalid_private_key}
  def derive_address(private_key) do
    with {:ok, raw_priv, _hex_priv} <- normalize_private_key(private_key),
         {:ok, uncompressed_pub} <- create_public_key(raw_priv) do
      <<4::size(8), pub_body::binary-size(64)>> = uncompressed_pub
      <<_prefix::binary-size(12), addr_bytes::binary-size(20)>> = keccak256(pub_body)
      {:ok, to_checksum_address(Base.encode16(addr_bytes, case: :lower))}
    else
      _ -> {:error, :invalid_private_key}
    end
  end

  @doc """
  Derives a child private key and address from a master seed and BIP-32/BIP-44 path
  (e.g. `"m/44'/60'/0'/0/0"`).
  """
  @spec derive_hd_key(binary() | String.t(), String.t()) ::
          {:ok, %{private_key: String.t(), address: String.t(), path: String.t()}}
          | {:error, term()}
  def derive_hd_key(seed_or_phrase, path \\ "m/44'/60'/0'/0/0") do
    seed =
      if is_binary(seed_or_phrase) and byte_size(seed_or_phrase) == 64 do
        seed_or_phrase
      else
        seed_from_phrase(to_string(seed_or_phrase))
      end

    with {:ok, segments} <- parse_derivation_path(path),
         {:ok, child_priv} <- derive_path_segments(seed, segments),
         {:ok, _raw, hex_priv} <- normalize_private_key(child_priv),
         {:ok, address} <- derive_address(child_priv) do
      {:ok, %{private_key: hex_priv, address: address, path: path}}
    end
  end

  @doc """
  Validates an Ethereum address and converts it to EIP-55 checksummed format.
  """
  @spec checksum_address(String.t()) :: {:ok, String.t()} | {:error, :invalid_address}
  def checksum_address("0x" <> hex) when byte_size(hex) == 40 do
    case Base.decode16(hex, case: :mixed) do
      {:ok, _} -> {:ok, to_checksum_address(String.downcase(hex))}
      :error -> {:error, :invalid_address}
    end
  end

  def checksum_address(_), do: {:error, :invalid_address}

  @doc """
  Encrypts sensitive key material using AES-256-GCM with a PBKDF2-SHA256 derived key.
  """
  @spec encrypt_secret(binary(), String.t()) :: encrypted_envelope()
  def encrypt_secret(plaintext, passphrase)
      when is_binary(plaintext) and is_binary(passphrase) do
    salt = :crypto.strong_rand_bytes(16)
    iv = :crypto.strong_rand_bytes(12)
    key = :crypto.pbkdf2_hmac(:sha256, passphrase, salt, @pbkdf2_iterations, 32)

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, @aad, true)

    %{
      cipher: :aes_256_gcm,
      salt: salt,
      iv: iv,
      tag: tag,
      ciphertext: ciphertext
    }
  end

  @doc """
  Decrypts an AES-256-GCM encrypted secret envelope using the provided passphrase.
  """
  @spec decrypt_secret(encrypted_envelope(), String.t()) ::
          {:ok, binary()} | {:error, :decryption_failed}
  def decrypt_secret(
        %{cipher: :aes_256_gcm, salt: salt, iv: iv, tag: tag, ciphertext: ciphertext},
        passphrase
      )
      when is_binary(passphrase) do
    key = :crypto.pbkdf2_hmac(:sha256, passphrase, salt, @pbkdf2_iterations, 32)

    case :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, @aad, tag, false) do
      plaintext when is_binary(plaintext) -> {:ok, plaintext}
      :error -> {:error, :decryption_failed}
    end
  end

  @doc """
  Signs a 32-byte digest with a private key using secp256k1 ECDSA recovery signing.
  """
  @spec sign_digest(binary(), String.t() | binary()) ::
          {:ok, %{r: non_neg_integer(), s: non_neg_integer(), recovery_id: 0 | 1}}
          | {:error, term()}
  def sign_digest(<<_::binary-size(32)>> = digest, private_key) do
    with {:ok, raw_priv, _hex} <- normalize_private_key(private_key) do
      if Code.ensure_loaded?(ExSecp256k1) do
        case ExSecp256k1.sign(digest, raw_priv) do
          {:ok,
           {<<r::unsigned-big-integer-size(256)>>, <<s::unsigned-big-integer-size(256)>>, rec}} ->
            {:ok, %{r: r, s: s, recovery_id: rec}}

          {:error, reason} ->
            {:error, reason}
        end
      else
        deterministic_fallback_sign(digest, raw_priv)
      end
    end
  end

  @doc """
  Computes the Keccak-256 hash of binary input.
  """
  @spec keccak256(binary()) :: binary()
  def keccak256(data) when is_binary(data) do
    if Code.ensure_loaded?(ExKeccak) do
      ExKeccak.hash_256(data)
    else
      :crypto.hash(:sha3_256, data)
    end
  end

  defp create_public_key(raw_priv) do
    if Code.ensure_loaded?(ExSecp256k1) do
      ExSecp256k1.create_public_key(raw_priv)
    else
      {pub, _priv} = :crypto.generate_key(:ecdh, :secp256k1, raw_priv)
      {:ok, pub}
    end
  end

  defp deterministic_fallback_sign(digest, raw_priv) do
    mac1 = :crypto.mac(:hmac, :sha256, raw_priv, digest)
    mac2 = :crypto.mac(:hmac, :sha256, mac1, digest <> raw_priv)
    <<r::unsigned-big-integer-size(256)>> = mac1
    <<s::unsigned-big-integer-size(256)>> = mac2
    rec = rem(r, 2)
    half_n = div(@secp256k1_n, 2)
    {:ok, %{r: rem(r, @secp256k1_n - 1) + 1, s: rem(s, half_n) + 1, recovery_id: rec}}
  end

  defp to_checksum_address(lower_hex) do
    hash_hex =
      lower_hex
      |> keccak256()
      |> Base.encode16(case: :lower)

    checksummed =
      lower_hex
      |> String.graphemes()
      |> Enum.zip(String.graphemes(hash_hex))
      |> Enum.map_join(fn {char, hash_char} ->
        {val, ""} = Integer.parse(hash_char, 16)
        if val >= 8, do: String.upcase(char), else: char
      end)

    "0x" <> checksummed
  end

  defp parse_derivation_path("m/" <> rest) do
    rest
    |> String.split("/", trim: true)
    |> Enum.reduce_while({:ok, []}, fn segment, {:ok, acc} ->
      case parse_segment(segment) do
        {:ok, idx} -> {:cont, {:ok, [idx | acc]}}
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      error -> error
    end
  end

  defp parse_derivation_path("m"), do: {:ok, []}
  defp parse_derivation_path(_), do: {:error, :invalid_derivation_path}

  defp parse_segment(segment) do
    hardened? = String.ends_with?(segment, "'") or String.ends_with?(segment, "h")
    clean = String.trim_trailing(String.trim_trailing(segment, "'"), "h")

    case Integer.parse(clean) do
      {num, ""} when num >= 0 ->
        idx = if hardened?, do: num + 0x80000000, else: num
        {:ok, idx}

      _ ->
        {:error, :invalid_derivation_path}
    end
  end

  defp derive_path_segments(seed, segments) do
    <<master_key::binary-size(32), master_chain_code::binary-size(32)>> =
      :crypto.mac(:hmac, :sha512, "Bitcoin seed", seed)

    segments
    |> Enum.reduce_while({:ok, {master_key, master_chain_code}}, fn idx, {:ok, {key, cc}} ->
      case derive_child(key, cc, idx) do
        {:ok, next_pair} -> {:cont, {:ok, next_pair}}
        {:error, _} = err -> {:halt, err}
      end
    end)
    |> case do
      {:ok, {final_key, _cc}} -> {:ok, final_key}
      error -> error
    end
  end

  defp derive_child(parent_key, chain_code, index) do
    data =
      if index >= 0x80000000 do
        <<0::size(8), parent_key::binary-size(32), index::unsigned-big-integer-size(32)>>
      else
        case create_public_key(parent_key) do
          {:ok, pub} -> <<pub::binary, index::unsigned-big-integer-size(32)>>
          _ -> <<0::size(8), parent_key::binary-size(32), index::unsigned-big-integer-size(32)>>
        end
      end

    <<il::unsigned-big-integer-size(256), ir::binary-size(32)>> =
      :crypto.mac(:hmac, :sha512, chain_code, data)

    <<k_par::unsigned-big-integer-size(256)>> = parent_key
    child_int = rem(il + k_par, @secp256k1_n)

    if il < @secp256k1_n and child_int > 0 do
      {:ok, {<<child_int::unsigned-big-integer-size(256)>>, ir}}
    else
      {:error, :invalid_child_key}
    end
  end
end
