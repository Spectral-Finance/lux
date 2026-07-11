defmodule LuxAppWeb.Auth.Siwe do
  @moduledoc """
  SIWE (Sign-In with Ethereum) EIP-4361 verification logic.
  Handles parsing and cryptographic signature verification.
  """

  def verify_signature(message, signature, expected_nonce) do
    with {:ok, parsed} <- parse_message(message),
         :ok <- verify_nonce(parsed.nonce, expected_nonce),
         :ok <- check_signature(message, signature, parsed.address) do
      {:ok, parsed.address}
    else
      err -> err
    end
  end

  def parse_message(message) do
    # Regex to extract the Ethereum address and nonce
    address_regex = ~r/([a-zA-Z0-9\.-]+) wants you to sign in with your Ethereum account:\n(0x[a-fA-F0-9]{40})/
    nonce_regex = ~r/Nonce: ([a-zA-Z0-9]+)/

    address_match = Regex.run(address_regex, message)
    nonce_match = Regex.run(nonce_regex, message)

    if address_match && nonce_match do
      [_, _domain, address] = address_match
      [_, nonce] = nonce_match
      {:ok, %{address: String.downcase(address), nonce: nonce}}
    else
      {:error, :invalid_siwe_message}
    end
  end

  def verify_nonce(nonce, expected_nonce) do
    if nonce == expected_nonce do
      :ok
    else
      {:error, :nonce_mismatch}
    end
  end

  def check_signature(message, signature, expected_address) do
    message_length = byte_size(message)
    eth_message = "\x19Ethereum Signed Message:\n#{message_length}#{message}"
    
    hash = ExKeccak.hash_256(eth_message)
    
    sig_bytes = Base.decode16!(String.replace(signature, "0x", ""), case: :mixed)
    
    if byte_size(sig_bytes) == 65 do
      <<r::binary-size(32), s::binary-size(32), v::integer>> = sig_bytes
      
      recovery_id = if v >= 27, do: v - 27, else: v
      
      case ExSecp256k1.recover(hash, r <> s, recovery_id) do
        {:ok, pubkey} ->
          <<4::integer, uncompressed_pubkey::binary-size(64)>> = pubkey
          pub_hash = ExKeccak.hash_256(uncompressed_pubkey)
          
          <<_::binary-size(12), address_bytes::binary-size(20)>> = pub_hash
          recovered_address = "0x" <> Base.encode16(address_bytes, case: :lower)
          
          if String.downcase(expected_address) == recovered_address do
            :ok
          else
            {:error, :invalid_signature}
          end
        _ ->
          {:error, :recovery_failed}
      end
    else
      {:error, :invalid_signature_length}
    end
  rescue
    _ -> {:error, :signature_verification_crashed}
  end
end
