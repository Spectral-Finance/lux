defmodule Lux.Web3.Auth.Signature do
  @moduledoc """
  Ethereum personal-sign helpers for SIWE authentication.

  The verifier recovers the signer from a 65-byte recoverable ECDSA signature,
  derives the Ethereum address from the recovered public key, and compares it
  against the address declared in the SIWE message.
  """

  alias Lux.Web3.Auth.Siwe

  @spec personal_hash(String.t()) :: binary()
  def personal_hash(message) when is_binary(message) do
    ExKeccak.hash_256("\x19Ethereum Signed Message:\n#{byte_size(message)}" <> message)
  end

  @spec verify(String.t(), String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def verify(message, signature_hex, expected_address)
      when is_binary(message) and is_binary(signature_hex) and is_binary(expected_address) do
    expected_address = Siwe.normalize_address(expected_address)

    with {:ok, recovered_address} <- recover_address(message, signature_hex) do
      if recovered_address == expected_address do
        {:ok, recovered_address}
      else
        {:error, "SIWE signature signer does not match message address"}
      end
    end
  end

  def verify(_, _, _), do: {:error, "Invalid signature verification input"}

  @spec recover_address(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def recover_address(message, signature_hex) do
    with {:ok, <<r::binary-size(32), s::binary-size(32), v::integer-size(8)>>} <- decode_signature(signature_hex),
         {:ok, recovery_id} <- normalize_recovery_id(v),
         {:ok, public_key} <- ExSecp256k1.recover_compact(personal_hash(message), r <> s, recovery_id) do
      {:ok, address_from_public_key(public_key)}
    else
      {:error, reason} when is_binary(reason) -> {:error, reason}
      {:error, reason} -> {:error, "Unable to recover SIWE signer: #{inspect(reason)}"}
      reason -> {:error, "Unable to recover SIWE signer: #{inspect(reason)}"}
    end
  end

  @spec sign_for_tests(String.t(), binary()) :: {:ok, String.t()} | {:error, term()}
  def sign_for_tests(message, private_key) when is_binary(message) and is_binary(private_key) do
    with {:ok, {signature, recovery_id}} <- ExSecp256k1.sign_compact(personal_hash(message), private_key) do
      {:ok, "0x" <> Base.encode16(signature <> <<recovery_id + 27>>, case: :lower)}
    end
  end

  defp decode_signature(signature_hex) do
    signature_hex
    |> String.trim()
    |> String.replace_prefix("0x", "")
    |> Base.decode16(case: :mixed)
    |> case do
      {:ok, signature} when byte_size(signature) == 65 -> {:ok, signature}
      {:ok, _} -> {:error, "SIWE signature must be 65 bytes"}
      :error -> {:error, "SIWE signature must be hex encoded"}
    end
  end

  defp normalize_recovery_id(v) when v in [0, 1], do: {:ok, v}
  defp normalize_recovery_id(v) when v in [27, 28], do: {:ok, v - 27}
  defp normalize_recovery_id(v), do: {:error, "Invalid SIWE signature recovery id #{v}"}

  defp address_from_public_key(<<4, public_key::binary-size(64)>>), do: hash_public_key(public_key)
  defp address_from_public_key(public_key), do: hash_public_key(public_key)

  defp hash_public_key(public_key) do
    <<_::binary-size(12), address::binary-size(20)>> = ExKeccak.hash_256(public_key)
    "0x" <> Base.encode16(address, case: :lower)
  end
end
