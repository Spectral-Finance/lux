defmodule Lux.Web3.Auth.Signature do
  @moduledoc """
  Ethereum personal-sign signature recovery and verification helpers.
  """

  @type address :: String.t()
  @type signature :: String.t() | binary()

  @doc """
  Hashes a message using the EIP-191 personal-sign prefix.
  """
  @spec personal_hash(String.t()) :: binary()
  def personal_hash(message) when is_binary(message) do
    ExKeccak.hash_256("\x19Ethereum Signed Message:\n#{byte_size(message)}#{message}")
  end

  @doc """
  Recovers the Ethereum address that signed a personal-sign message.
  """
  @spec recover_address(String.t(), signature()) :: {:ok, address()} | {:error, term()}
  def recover_address(message, signature) when is_binary(message) do
    with {:ok, {compact_signature, recovery_id}} <- decode_signature(signature),
         {:ok, public_key} <-
           ExSecp256k1.recover_compact(personal_hash(message), compact_signature, recovery_id) do
      {:ok, Ethers.Utils.public_key_to_address(public_key)}
    end
  end

  @doc """
  Verifies that a personal-sign signature recovers to the expected address.
  """
  @spec verify_personal_signature(String.t(), signature(), address()) :: :ok | {:error, term()}
  def verify_personal_signature(message, signature, expected_address) do
    with {:ok, recovered} <- recover_address(message, signature) do
      if same_address?(recovered, expected_address), do: :ok, else: {:error, :signature_mismatch}
    end
  end

  @doc """
  Returns true for 20-byte hex Ethereum addresses.
  """
  @spec valid_address?(term()) :: boolean()
  def valid_address?("0x" <> rest), do: Regex.match?(~r/^[0-9a-fA-F]{40}$/, rest)
  def valid_address?(_address), do: false

  @doc """
  Normalizes an Ethereum address for lookups and comparisons.
  """
  @spec normalize_address(address()) :: address()
  def normalize_address(address) when is_binary(address), do: String.downcase(address)

  @doc """
  Compares addresses case-insensitively.
  """
  @spec same_address?(address(), address()) :: boolean()
  def same_address?(left, right) when is_binary(left) and is_binary(right) do
    normalize_address(left) == normalize_address(right)
  end

  def same_address?(_left, _right), do: false

  defp decode_signature("0x" <> signature), do: decode_hex_signature(signature)
  defp decode_signature(<<"0X", signature::binary>>), do: decode_hex_signature(signature)

  defp decode_signature(<<_::binary-size(65)>> = signature) do
    parse_signature(signature)
  end

  defp decode_signature(signature) when is_binary(signature) and byte_size(signature) == 130 do
    decode_hex_signature(signature)
  end

  defp decode_signature(_signature), do: {:error, :invalid_signature_format}

  defp decode_hex_signature(signature) do
    with {:ok, decoded} <- Base.decode16(signature, case: :mixed) do
      parse_signature(decoded)
    else
      :error -> {:error, :invalid_signature_encoding}
    end
  end

  defp parse_signature(<<r::binary-size(32), s::binary-size(32), v::8>>) do
    with {:ok, recovery_id} <- recovery_id(v) do
      {:ok, {r <> s, recovery_id}}
    end
  end

  defp parse_signature(_signature), do: {:error, :invalid_signature_length}

  defp recovery_id(v) when v in 0..1, do: {:ok, v}
  defp recovery_id(v) when v in 27..28, do: {:ok, v - 27}
  defp recovery_id(v) when v >= 35, do: {:ok, rem(v - 35, 2)}
  defp recovery_id(_v), do: {:error, :invalid_recovery_id}
end
