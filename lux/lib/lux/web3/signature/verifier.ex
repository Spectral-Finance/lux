defmodule Lux.Web3.Signature.Verifier do
  @moduledoc """
  Signature verification for Ethereum addresses.

  Supports:
  - Personal sign messages (EIP-191 prefixed)
  - Typed structured data (EIP-712)
  - ECDSA recovery of signer address from signatures
  - Multi-signature aggregation and threshold checking

  Uses ex_secp256k1 for curve operations and ethers for address encoding.
  """

  alias Lux.Web3.Schemas.AuditLog

  @doc """
  Recover the Ethereum address from a signed message and signature.

  Args:
  - message: the original message bytes
  - signature: binary signature (r || s || v format)

  Returns {:ok, address} or {:error, reason}
  """
  @spec recover_address(binary(), binary()) :: {:ok, String.t()} | {:error, term()}
  def recover_address(message, signature) when byte_size(signature) == 65 do
    <<v::8, r::binary(32), s::binary(32)>> = signature

    with {:ok, pubkey} <- recover_pubkey(message, r, s, v),
         {:ok, address} <- pubkey_to_address(pubkey) do
      AuditLog.create(:signature_verified, address, %{
        method: :personal_sign,
        message_hash: Base.encode16(message, case: :lower)
      })

      {:ok, address}
    end
  end

  def recover_address(_message, _signature) do
    {:error, :invalid_signature_length}
  end

  @doc """
  Verify a signature matches an address for a given message.

  Recovers the signer from the signature and compares to the expected address.
  """
  @spec verify_signature(String.t(), binary(), binary()) :: boolean()
  def verify_signature(address, message, signature) do
    case recover_address(message, signature) do
      {:ok, recovered} -> String.downcase(recovered) == String.downcase(address)
      _ -> false
    end
  end

  @doc """
  Hash a message for signing using EIP-191 personal_sign format.
  """
  @spec hash_personal_message(binary()) :: binary()
  def hash_personal_message(message) when is_binary(message) do
    encoded = "\x19Ethereum Signed Message:\n#{byte_size(message)}#{message}"
    :crypto.hash(:keccak_256, encoded)
  end

  @doc """
  Hash a message for signing using EIP-191 typed data format.
  """
  @spec hash_typed_data(binary()) :: binary()
  def hash_typed_data(data) when is_binary(data) do
    prefix = <<0x16, 0x01, 0x00>>
    :crypto.hash(:keccak_256, prefix <> data)
  end

  @doc """
  Verify multiple signatures against a threshold (multi-sig).
  """
  @spec verify_multisig(binary(), [{binary(), binary()}], non_neg_integer()) ::
          {:ok, [String.t()]} | {:error, String.t()}
        when bymessage: binary(),
             bysignature: binary(),
             threshold: non_neg_integer()
  def verify_multisig(message, sig_pairs, threshold) do
    valid_signers =
      Enum.map(sig_pairs, fn {signature, _meta} ->
        case recover_address(message, signature) do
          {:ok, addr} -> {:ok, addr}
          {:error, _} -> :error
        end
      end)
      |> Enum.filter(fn
        {:ok, _} -> true
        _ -> false
      end)
      |> Enum.map(fn {:ok, addr} -> addr end)

    if length(valid_signers) >= threshold do
      AuditLog.create(:multisig_approved, List.first(valid_signers), %{
        valid_signers: valid_signers,
        threshold: threshold,
        total_signed: length(sig_pairs)
      })

      {:ok, valid_signers}
    else
      AuditLog.create(:signature_failed, message, %{
        reason: :insufficient_signatures,
        valid: length(valid_signers),
        required: threshold
      })

      {:error,
       "Insufficient signatures: got #{length(valid_signers)}, need #{threshold}"}
    end
  end

  @doc """
  Sign a message with a private key.
  """
  @spec sign_message(binary(), binary()) :: {:ok, binary()} | {:error, term()}
  def sign_message(private_key, message) when is_binary(private_key) and is_binary(message) do
    hashed = hash_personal_message(message)

    case :ex_secp256k1.sign(hashed, private_key) do
      {:ok, {r, s}} ->
        {:ok, <<r::256, s::256>>}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Internal helpers

  defp recover_pubkey(message, r, s, v) do
    recovery_id = v - 27

    case :ex_secp256k1.recover(message, r, s, recovery_id) do
      {:ok, pubkey} -> {:ok, pubkey}
      _ -> {:error, :unable_to_recover_pubkey}
    end
  end

  defp pubkey_to_address(pubkey) do
    byte_size = byte_size(pubkey)

    x =
      case byte_size do
        65 -> pubkey |> :binary.part(1, 32)
        33 -> pubkey |> :binary.part(1, 32)
        _ -> pubkey
      end

    hash = :crypto.hash(:keccak_256, x)
    address_bytes = :binary.part(hash, 10, 20)
    {:ok, "0x" <> Base.encode16(address_bytes, case: :lower)}
  end
end
