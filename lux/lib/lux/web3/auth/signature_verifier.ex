defmodule Lux.Web3.Auth.SignatureVerifier do
  @moduledoc """
  Verifies Ethereum signatures for SIWE and arbitrary messages.

  Supports:
  - Personal sign (EIP-191) verification
  - EIP-712 typed data hashing
  - Address recovery from signature
  """

  @doc """
  Verify that a signature was produced by the claimed address.

  Uses EIP-191 personal sign prefix: "\\x19Ethereum Signed Message:\\n{length}{message}"
  """
  def verify(message, signature, expected_address) do
    case recover_address(message, signature) do
      {:ok, recovered} ->
        if String.downcase(recovered) == String.downcase(expected_address) do
          :ok
        else
          {:error, :signature_mismatch}
        end

      error ->
        error
    end
  end

  @doc "Recover the signer address from a personal_sign signature."
  def recover_address(message, signature) do
    with {:ok, sig_bytes} <- decode_signature(signature),
         {:ok, {r, s, v}} <- parse_rsv(sig_bytes) do
      # EIP-191 prefix
      prefixed = "\x19Ethereum Signed Message:\n#{byte_size(message)}#{message}"
      hash = :crypto.hash(:sha3_256, prefixed)

      case ExSecp256k1.recover_compact(hash, r <> s, recovery_id(v)) do
        {:ok, public_key} ->
          address = public_key_to_address(public_key)
          {:ok, address}
        {:error, reason} ->
          {:error, {:recovery_failed, reason}}
      end
    end
  end

  @doc "Hash a message with EIP-191 personal sign prefix."
  def personal_hash(message) do
    prefixed = "\x19Ethereum Signed Message:\n#{byte_size(message)}#{message}"
    :crypto.hash(:sha3_256, prefixed)
  end

  defp decode_signature("0x" <> hex), do: Base.decode16(hex, case: :mixed)
  defp decode_signature(hex) when byte_size(hex) == 130 do
    Base.decode16(hex, case: :mixed)
  end
  defp decode_signature(bin) when byte_size(bin) == 65, do: {:ok, bin}
  defp decode_signature(_), do: {:error, :invalid_signature_format}

  defp parse_rsv(<<r::binary-size(32), s::binary-size(32), v::8>>) do
    {:ok, {r, s, v}}
  end
  defp parse_rsv(_), do: {:error, :invalid_signature_length}

  defp recovery_id(v) when v >= 27, do: v - 27
  defp recovery_id(v), do: v

  defp public_key_to_address(<<4, key::binary-size(64)>>) do
    <<_::binary-size(12), addr::binary-size(20)>> = :crypto.hash(:sha3_256, key)
    "0x" <> Base.encode16(addr, case: :lower)
  end
  defp public_key_to_address(key) when byte_size(key) == 65 do
    <<_, rest::binary-size(64)>> = key
    <<_::binary-size(12), addr::binary-size(20)>> = :crypto.hash(:sha3_256, rest)
    "0x" <> Base.encode16(addr, case: :lower)
  end
end
