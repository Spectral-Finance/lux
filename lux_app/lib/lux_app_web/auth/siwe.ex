defmodule LuxAppWeb.Auth.Siwe do
  @moduledoc """
  SIWE (Sign-In with Ethereum) EIP-4361 verification logic bound to chain ID.
  """
  alias LuxAppWeb.Auth.AuditLogger

  def verify_signature(message, signature, expected_nonce, expected_domain, expected_uri, expected_chain_id) do
    result = 
      with {:ok, parsed} <- parse_message(message),
           :ok <- verify_domain(parsed.domain, expected_domain),
           :ok <- verify_uri(parsed.uri, expected_uri),
           :ok <- verify_version(parsed.version),
           :ok <- verify_chain_id(parsed.chain_id, expected_chain_id),
           :ok <- verify_nonce(parsed.nonce, expected_nonce),
           :ok <- verify_issued_at(parsed.issued_at),
           :ok <- verify_not_before(parsed.not_before),
           :ok <- verify_expiration(parsed.expiration_time),
           :ok <- check_signature(message, signature, parsed.address, parsed.chain_id) do
        {:ok, parsed.address}
      else
        err -> err
      end

    case result do
      {:ok, addr} ->
        AuditLogger.log_login_success(addr, expected_chain_id)
        {:ok, addr}
      {:error, reason} ->
        AuditLogger.log_login_failure(expected_domain, reason)
        {:error, reason}
    end
  end

  def parse_message(message) do
    regex = ~r/^(?<domain>[a-zA-Z0-9\.-]+(?::\d+)?) wants you to sign in with your Ethereum account:\n(?<address>0x[a-fA-F0-9]{40})\n\n(?:(?<statement>[^\n]+)\n\n)?URI: (?<uri>[^\n]+)\nVersion: (?<version>\d+)\nChain ID: (?<chain_id>\d+)\nNonce: (?<nonce>[a-zA-Z0-9]+)\nIssued At: (?<issued_at>[^\n]+)(?:\nExpiration Time: (?<expiration_time>[^\n]+))?(?:\nNot Before: (?<not_before>[^\n]+))?(?:\nRequest ID: (?<request_id>[^\n]+))?(?:\nResources:\n(?<resources>.*))?$/s

    case Regex.named_captures(regex, message) do
      nil -> {:error, :invalid_siwe_message}
      captures ->
        {:ok, %{
          domain: captures["domain"],
          address: String.downcase(captures["address"]),
          statement: captures["statement"],
          uri: captures["uri"],
          version: captures["version"],
          chain_id: captures["chain_id"],
          nonce: captures["nonce"],
          issued_at: captures["issued_at"],
          expiration_time: if(captures["expiration_time"] == "", do: nil, else: captures["expiration_time"]),
          not_before: if(captures["not_before"] == "", do: nil, else: captures["not_before"])
        }}
    end
  end

  def verify_domain(domain, expected_domain) do
    if domain == expected_domain, do: :ok, else: {:error, :domain_mismatch}
  end

  def verify_uri(uri, expected_uri) do
    if uri == expected_uri, do: :ok, else: {:error, :uri_mismatch}
  end

  def verify_version(version) do
    if version == "1", do: :ok, else: {:error, :invalid_version}
  end

  def verify_chain_id(chain_id, expected_chain_id) do
    if to_string(chain_id) == to_string(expected_chain_id), do: :ok, else: {:error, :chain_id_mismatch}
  end

  def verify_nonce(nonce, expected_nonce) do
    if nonce == expected_nonce, do: :ok, else: {:error, :nonce_mismatch}
  end

  def verify_issued_at(issued_at) do
    case DateTime.from_iso8601(issued_at) do
      {:ok, iat_dt, _offset} ->
        now = DateTime.utc_now()
        max_allowed = DateTime.add(now, 60, :second)

        if DateTime.compare(iat_dt, max_allowed) == :gt do
          {:error, :issued_at_in_future}
        else
          :ok
        end

      _ -> {:error, :invalid_issued_at_format}
    end
  end

  def verify_not_before(nil), do: :ok
  def verify_not_before(not_before) do
    case DateTime.from_iso8601(not_before) do
      {:ok, nbf_dt, _offset} ->
        now = DateTime.utc_now()
        if DateTime.compare(now, nbf_dt) == :lt do
          {:error, :message_not_yet_valid}
        else
          :ok
        end

      _ -> {:error, :invalid_not_before_format}
    end
  end

  def verify_expiration(nil), do: :ok
  def verify_expiration(expiration_time) do
    case DateTime.from_iso8601(expiration_time) do
      {:ok, exp_dt, _offset} ->
        now = DateTime.utc_now()
        if DateTime.compare(exp_dt, now) == :gt do
          :ok
        else
          {:error, :expired_message}
        end

      _ -> {:error, :invalid_expiration_format}
    end
  end

  def check_signature(message, signature, expected_address, chain_id) do
    message_length = byte_size(message)
    eth_message = "\x19Ethereum Signed Message:\n#{message_length}#{message}"
    
    hash = ExKeccak.hash_256(eth_message)
    clean_sig = String.replace(signature, "0x", "")
    
    case Base.decode16(clean_sig, case: :mixed) do
      {:ok, <<r::binary-size(32), s::binary-size(32), v::integer>>} ->
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
              check_multisig_fallback(message, signature, expected_address, chain_id)
            end
          _ ->
            check_multisig_fallback(message, signature, expected_address, chain_id)
        end
      _ ->
        check_multisig_fallback(message, signature, expected_address, chain_id)
    end
  end

  defp check_multisig_fallback(message, signature, expected_address, chain_id) do
    verifier = Application.get_env(:lux_app, :eip1271_verifier, LuxAppWeb.Auth.RPCVerifier)
    if verifier.is_valid_signature?(message, signature, expected_address, chain_id) do
      :ok
    else
      {:error, :invalid_signature_and_fallback_failed}
    end
  end
end
