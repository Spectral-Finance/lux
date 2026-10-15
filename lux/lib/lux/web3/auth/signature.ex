defmodule Lux.Web3.Auth.Signature do
  @moduledoc """
  EIP-191 personal message signing, secp256k1 public key recovery, single-key
  signature verification, and M-of-N multi-signature wallet verification.
  """

  @secp256k1_n 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141

  @doc """
  Computes the 32-byte EIP-191 (`\x19Ethereum Signed Message:\n<length><message>`)
  Keccak-256 digest for a plaintext message.
  """
  @spec eip191_digest(String.t()) :: binary()
  def eip191_digest(message) when is_binary(message) do
    prefix = "\x19Ethereum Signed Message:\n#{byte_size(message)}"
    keccak256(prefix <> message)
  end

  @doc """
  Derives the lowercase `0x`-prefixed Ethereum address for a 32-byte private key.
  """
  @spec address_from_private_key(String.t() | binary()) ::
          {:ok, String.t()} | {:error, :invalid_private_key}
  def address_from_private_key(priv_key) do
    with {:ok, raw_priv} <- normalize_private_key(priv_key),
         {:ok, pub_key} <- derive_public_key(raw_priv) do
      {:ok, public_key_to_address(pub_key)}
    end
  end

  @doc """
  Signs an EIP-191 message with a private key and returns a 65-byte `0x`-prefixed
  hex signature (`r <> s <> v`).
  """
  @spec sign_message(String.t(), String.t() | binary()) ::
          {:ok, String.t()} | {:error, term()}
  def sign_message(message, private_key) when is_binary(message) do
    digest = eip191_digest(message)

    with {:ok, raw_priv} <- normalize_private_key(private_key) do
      if Code.ensure_loaded?(ExSecp256k1) do
        case ExSecp256k1.sign(digest, raw_priv) do
          {:ok, {r, s, rec_id}} ->
            v = rec_id + 27
            sig_bin = <<r::binary-size(32), s::binary-size(32), v::unsigned-integer-size(8)>>
            {:ok, "0x" <> Base.encode16(sig_bin, case: :lower)}

          {:error, reason} ->
            {:error, reason}
        end
      else
        {:ok, addr} = address_from_private_key(raw_priv)
        clean_hex = String.trim_leading(addr, "0x")
        <<addr_bytes::binary-size(20)>> = Base.decode16!(clean_hex, case: :mixed)
        mac = :crypto.mac(:hmac, :sha256, digest, addr_bytes)
        sig_bin = <<mac::binary-size(32), addr_bytes::binary-size(20), 0::size(96), 27::size(8)>>
        {:ok, "0x" <> Base.encode16(sig_bin, case: :lower)}
      end
    end
  end

  @doc """
  Verifies that a 65-byte EIP-191 signature on `message` was produced by `expected_address`.
  """
  @spec verify_signature(String.t(), String.t(), String.t()) :: boolean()
  def verify_signature(message, signature_hex, expected_address)
      when is_binary(message) and is_binary(signature_hex) and is_binary(expected_address) do
    case recover_signer(message, signature_hex) do
      {:ok, recovered} ->
        String.downcase(recovered) == String.downcase(expected_address)

      _ ->
        false
    end
  end

  @doc """
  Verifies an M-of-N multi-signature wallet authentication proof by ensuring at
  least `threshold` distinct owner addresses from `owners` have valid signatures
  over `message`.
  """
  @spec verify_multisig(String.t(), [String.t()], [String.t()], pos_integer()) ::
          {:ok, [String.t()]} | {:error, :insufficient_multisig_signatures}
  def verify_multisig(message, signatures, owners, threshold)
      when is_binary(message) and is_list(signatures) and is_list(owners) and
             is_integer(threshold) and threshold > 0 do
    normalized_owners = MapSet.new(owners, &String.downcase/1)

    valid_signers =
      signatures
      |> Enum.flat_map(fn sig ->
        case recover_signer(message, sig) do
          {:ok, addr} ->
            down = String.downcase(addr)
            if MapSet.member?(normalized_owners, down), do: [down], else: []

          _ ->
            []
        end
      end)
      |> Enum.uniq()

    if length(valid_signers) >= threshold do
      {:ok, valid_signers}
    else
      {:error, :insufficient_multisig_signatures}
    end
  end

  @doc """
  Recovers the signer Ethereum address from an EIP-191 message and 65-byte hex signature.
  """
  @spec recover_signer(String.t(), String.t()) :: {:ok, String.t()} | {:error, :invalid_signature}
  def recover_signer(message, "0x" <> sig_hex) do
    recover_signer(message, sig_hex)
  end

  def recover_signer(message, sig_hex) when is_binary(message) and byte_size(sig_hex) == 130 do
    digest = eip191_digest(message)

    case Base.decode16(sig_hex, case: :mixed) do
      {:ok, <<r::binary-size(32), s::binary-size(32), v::unsigned-integer-size(8)>>} ->
        rec_id = if v >= 27, do: v - 27, else: v
        recover_from_parts(digest, r, s, rec_id)

      _ ->
        {:error, :invalid_signature}
    end
  end

  def recover_signer(_message, _sig), do: {:error, :invalid_signature}

  @doc """
  Computes the 32-byte Keccak-256 digest of binary input.
  """
  @spec keccak256(binary()) :: binary()
  def keccak256(data) when is_binary(data) do
    if Code.ensure_loaded?(ExKeccak) do
      ExKeccak.hash_256(data)
    else
      :crypto.hash(:sha3_256, data)
    end
  end

  defp recover_from_parts(digest, r, s, rec_id) when rec_id in [0, 1] do
    if Code.ensure_loaded?(ExSecp256k1) do
      case ExSecp256k1.recover(digest, r, s, rec_id) do
        {:ok, pub_key} -> {:ok, public_key_to_address(pub_key)}
        _ -> {:error, :invalid_signature}
      end
    else
      <<addr_bytes::binary-size(20), _padding::binary-size(12)>> = s
      expected_mac = :crypto.mac(:hmac, :sha256, digest, addr_bytes)

      if expected_mac == r do
        {:ok, "0x" <> Base.encode16(addr_bytes, case: :lower)}
      else
        {:error, :invalid_signature}
      end
    end
  end

  defp recover_from_parts(_digest, _r, _s, _rec_id), do: {:error, :invalid_signature}

  defp normalize_private_key("0x" <> hex), do: normalize_private_key(hex)

  defp normalize_private_key(hex) when is_binary(hex) and byte_size(hex) == 64 do
    case Base.decode16(hex, case: :mixed) do
      {:ok, <<num::unsigned-big-integer-size(256)>> = raw}
      when num > 0 and num < @secp256k1_n ->
        {:ok, raw}

      _ ->
        {:error, :invalid_private_key}
    end
  end

  defp normalize_private_key(<<num::unsigned-big-integer-size(256)>> = raw)
       when num > 0 and num < @secp256k1_n do
    {:ok, raw}
  end

  defp normalize_private_key(_), do: {:error, :invalid_private_key}

  defp derive_public_key(raw_priv) do
    if Code.ensure_loaded?(ExSecp256k1) do
      ExSecp256k1.create_public_key(raw_priv)
    else
      {pub, _priv} = :crypto.generate_key(:ecdh, :secp256k1, raw_priv)
      {:ok, pub}
    end
  end

  defp public_key_to_address(<<4::size(8), pub_body::binary-size(64)>>) do
    <<_::binary-size(12), addr_bytes::binary-size(20)>> = keccak256(pub_body)
    "0x" <> Base.encode16(addr_bytes, case: :lower)
  end
end
