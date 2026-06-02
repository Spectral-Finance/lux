defmodule Lux.Web3.Auth.Verifier do
  @moduledoc """
  Signature verification for Web3 authentication.

  Provides utilities to verify Ethereum signatures against messages and
  recover signer addresses. Supports both personal_sign (eth_sign) and
  typed data (EIP-712) signature verification.
  """

  require Logger
  alias Lux.Web3.Auth.SIWE

  @typedoc "Signature verification result"
  @type verification_result :: {:ok, String.t()} | {:error, String.t()}

  @typedoc "Signature data"
  @type signature :: %{
          required(:message) => String.t(),
          required(:signature) => String.t(),
          optional(:address) => String.t()
        }

  @doc """
  Verifies a SIWE message and its signature.

  Returns `{:ok, address}` if the signature is valid and matches the message,
  or `{:error, reason}` otherwise.
  """
  @spec verify_siwe(SIWE.t(), String.t()) :: verification_result()
  def verify_siwe(%SIWE{} = siwe, signature) do
    with :ok <- SIWE.validate(siwe),
         false <- SIWE.expired?(siwe),
         false <- SIWE.not_yet_valid?(siwe),
         message <- SIWE.build_message(siwe),
         {:ok, recovered} <- recover_address(message, signature) do
      if String.downcase(recovered) == String.downcase(siwe.address) do
        {:ok, recovered}
      else
        {:error, "Signature does not match the claimed address"}
      end
    else
      {:error, reason} -> {:error, reason}
      true -> {:error, "SIWE message has expired"}
    end
  end

  @doc """
  Verifies an arbitrary message signature using personal_sign (EIP-191).

  Returns `{:ok, address}` if the signature is valid.
  """
  @spec verify_personal_sign(String.t(), String.t()) :: verification_result()
  def verify_personal_sign(message, signature) do
    recover_address(message, signature)
  end

  @doc """
  Verifies a typed data signature (EIP-712).

  Returns `{:ok, address}` if the signature is valid.
  """
  @spec verify_typed_data(map(), String.t()) :: verification_result()
  def verify_typed_data(typed_data, signature) do
    encoded = encode_typed_data(typed_data)
    recover_address(encoded, signature)
  end

  @doc """
  Recovers the Ethereum address from a signed message.

  Uses secp256k1 elliptic curve recovery to derive the public key
  from the signature hash and recover the signer's address.
  """
  @spec recover_address(String.t(), String.t()) :: verification_result()
  def recover_address(message, signature) do
    message_hash = hash_message(message)

    with {:ok, sig_bytes} <- decode_signature(signature),
         {:ok, pub_key} <- recover_public_key(message_hash, sig_bytes) do
      address = public_key_to_address(pub_key)
      {:ok, address}
    end
  end

  @doc """
  Validates that a given address matches the recovered signer.
  """
  @spec verify(address :: String.t(), message :: String.t(), signature :: String.t()) ::
          :ok | {:error, String.t()}
  def verify(address, message, signature) do
    case recover_address(message, signature) do
      {:ok, recovered} ->
        if String.downcase(recovered) == String.downcase(address) do
          :ok
        else
          {:error, "Signature does not match address"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp hash_message(message) do
    eth_prefix = "\x19Ethereum Signed Message:\n#{byte_size(message)}#{message}"
    :keccakf1600.hash(:sha3_256, eth_prefix)
  end

  defp decode_signature(sig) do
    sig = String.trim_leading(sig, "0x")
    sig_bytes = Base.decode16!(sig, case: :mixed)

    if byte_size(sig_bytes) != 65 do
      {:error, "Invalid signature length: expected 65 bytes"}
    else
      v = :binary.at(sig_bytes, 64)

      if v in [0, 1, 27, 28] do
        {:ok, sig_bytes}
      else
        {:error, "Invalid recovery id: #{v}"}
      end
    end
  rescue
    ArgumentError -> {:error, "Invalid hex signature"}
  end

  defp recover_public_key(message_hash, sig_bytes) do
    r =
      sig_bytes
      |> :binary.part(0, 32)
      |> :binary.bin_to_list()

    s =
      sig_bytes
      |> :binary.part(32, 32)
      |> :binary.bin_to_list()

    v = :binary.at(sig_bytes, 64)

    recovery_id =
      cond do
        v >= 27 -> v - 27
        true -> v
      end

    try do
      case :libsecp256k1.ecdsa_recover_compact(message_hash, r, s, recovery_id) do
        {:ok, pub_key} -> {:ok, pub_key}
        _ -> {:error, "Failed to recover public key"}
      end
    rescue
      _ -> {:error, "Secp256k1 recovery failed"}
    end
  end

  defp public_key_to_address(pub_key) do
    hash = :keccakf1600.hash(:sha3_256, pub_key)
    <<_::binary-size(12), addr::binary-size(20)>> = hash
    "0x" <> Base.encode16(addr, case: :lower)
  end

  defp encode_typed_data(typed_data) do
    typed_data
    |> Jason.encode!()
    |> then(&:keccakf1600.hash(:sha3_256, &1))
    |> Base.encode16(case: :lower)
  end
end
