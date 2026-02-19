defmodule Lux.Web3.Auth.SignatureVerifier do
  @moduledoc """
  Verifies Ethereum signatures for Web3 authentication.

  Supports:
  - `personal_sign` (EIP-191) message verification
  - `eth_signTypedData_v4` (EIP-712) typed data verification
  - Multi-chain address recovery

  Uses `ex_secp256k1` for ECDSA signature recovery, following the Ethereum
  personal message signing convention of prefixing messages with
  `"\\x19Ethereum Signed Message:\\n{length}"`.

  ## Examples

      iex> message = "Hello, world!"
      iex> # signature obtained from wallet.personal_sign(message)
      iex> {:ok, recovered_address} = SignatureVerifier.recover_address(message, signature)
      iex> SignatureVerifier.verify_signature(message, signature, expected_address)
      {:ok, true}
  """

  @ethereum_message_prefix "\x19Ethereum Signed Message:\n"

  @doc """
  Verifies that a message was signed by the expected Ethereum address.

  ## Parameters

    * `message` - The original message that was signed
    * `signature` - The hex-encoded signature (with or without "0x" prefix)
    * `expected_address` - The expected signer's Ethereum address

  ## Returns

    * `{:ok, true}` if the signature is valid and matches the expected address
    * `{:ok, false}` if the signature is valid but from a different address
    * `{:error, reason}` if the signature cannot be verified
  """
  @spec verify_signature(String.t(), String.t(), String.t()) ::
          {:ok, boolean()} | {:error, String.t()}
  def verify_signature(message, signature, expected_address) do
    case recover_address(message, signature) do
      {:ok, recovered} ->
        {:ok, addresses_equal?(recovered, expected_address)}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Recovers the Ethereum address that signed a message.

  Uses the Ethereum personal_sign convention (EIP-191) to hash the message
  and then recovers the public key from the signature using ECDSA recovery.

  ## Parameters

    * `message` - The original message that was signed
    * `signature` - The hex-encoded signature (65 bytes: r[32] || s[32] || v[1])

  ## Returns

    * `{:ok, address}` with the checksummed Ethereum address
    * `{:error, reason}` on failure
  """
  @spec recover_address(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def recover_address(message, signature) do
    with {:ok, sig_bytes} <- decode_signature(signature),
         {:ok, {r, s, v}} <- decompose_signature(sig_bytes),
         hash <- hash_personal_message(message),
         {:ok, public_key} <- recover_public_key(hash, r, s, v) do
      {:ok, public_key_to_address(public_key)}
    end
  end

  @doc """
  Verifies an EIP-712 typed data signature.

  ## Parameters

    * `typed_data_hash` - The pre-computed EIP-712 hash (32 bytes, hex-encoded)
    * `signature` - The hex-encoded signature
    * `expected_address` - The expected signer's Ethereum address

  ## Returns

    * `{:ok, true}` if the signature matches
    * `{:ok, false}` if it doesn't match
    * `{:error, reason}` on failure
  """
  @spec verify_typed_data(String.t(), String.t(), String.t()) ::
          {:ok, boolean()} | {:error, String.t()}
  def verify_typed_data(typed_data_hash, signature, expected_address) do
    with {:ok, hash_bytes} <- decode_hex(typed_data_hash),
         {:ok, sig_bytes} <- decode_signature(signature),
         {:ok, {r, s, v}} <- decompose_signature(sig_bytes),
         {:ok, public_key} <- recover_public_key(hash_bytes, r, s, v) do
      recovered = public_key_to_address(public_key)
      {:ok, addresses_equal?(recovered, expected_address)}
    end
  end

  @doc """
  Hashes a message according to the Ethereum personal_sign convention (EIP-191).

  Prepends the message with `"\\x19Ethereum Signed Message:\\n{length}"` and
  computes the Keccak-256 hash.
  """
  @spec hash_personal_message(String.t()) :: binary()
  def hash_personal_message(message) do
    prefixed = @ethereum_message_prefix <> Integer.to_string(byte_size(message)) <> message
    ExKeccak.hash_256(prefixed)
  end

  # Private helpers

  defp decode_signature(<<"0x", hex::binary>>), do: decode_hex(hex)
  defp decode_signature(hex) when is_binary(hex), do: decode_hex(hex)

  defp decode_hex(hex) do
    case Base.decode16(hex, case: :mixed) do
      {:ok, bytes} -> {:ok, bytes}
      :error -> {:error, "invalid hex encoding"}
    end
  end

  defp decompose_signature(<<r::binary-size(32), s::binary-size(32), v::8>>) do
    # Normalize v value: Ethereum uses 27/28, but secp256k1 recovery uses 0/1
    recovery_id =
      cond do
        v >= 27 -> v - 27
        v <= 1 -> v
        true -> v
      end

    {:ok, {r, s, recovery_id}}
  end

  defp decompose_signature(_), do: {:error, "invalid signature length (expected 65 bytes)"}

  defp recover_public_key(hash, r, s, recovery_id) do
    compact_sig = r <> s

    case ExSecp256k1.recover_compact(hash, compact_sig, recovery_id) do
      {:ok, public_key} ->
        {:ok, public_key}

      {:error, reason} ->
        {:error, "signature recovery failed: #{inspect(reason)}"}
    end
  end

  defp public_key_to_address(<<4, key::binary-size(64)>>) do
    # Uncompressed public key (65 bytes starting with 0x04)
    <<_::binary-size(12), address::binary-size(20)>> = ExKeccak.hash_256(key)
    "0x" <> Base.encode16(address, case: :lower)
  end

  defp public_key_to_address(<<key::binary-size(64)>>) do
    # Raw 64-byte public key
    <<_::binary-size(12), address::binary-size(20)>> = ExKeccak.hash_256(key)
    "0x" <> Base.encode16(address, case: :lower)
  end

  defp addresses_equal?(addr1, addr2) do
    String.downcase(addr1) == String.downcase(addr2)
  end
end
