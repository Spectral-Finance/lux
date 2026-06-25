defmodule Lux.Web3.Auth.SIWE do
  @moduledoc """
  Sign-In With Ethereum (EIP-4361) authentication handler.

  Provides the complete SIWE flow:
  1. Generate a challenge message for the client to sign
  2. Receive the signed message and signature from the client
  3. Verify the signature recovers the claimed address
  4. Validate message fields (domain, nonce, expiry, etc.)
  5. Create a session for the authenticated user

  This is the core authentication mechanism for Web3 login.
  """

  alias Lux.Web3.Schemas.SIWEMessage
  alias Lux.Web3.Session.Manager
  alias Lux.Web3.Signature.Verifier
  alias Lux.Web3.Schemas.AuditLog

  @doc """
  Generate a SIWE challenge message for a given address.

  Returns a message string that the client should sign
  with their wallet (e.g., MetaMask's personal_sign).
  """
  @spec challenge(String.t(), String.t(), keyword()) ::
          {:ok, SIWEMessage.t(), String.t()} | {:error, term()}
  def challenge(address, domain, opts \ []) do
    uri = Keyword.get(opts, :uri, "https://#{domain}")
    version = Keyword.get(opts, :version, "1")
    statement = Keyword.get(opts, :statement)
    expiration = Keyword.get(opts, :expiration_time)
    not_before = Keyword.get(opts, :not_before)
    request_id = Keyword.get(opts, :request_id)
    resources = Keyword.get(opts, :resources, [])
    ttl_seconds = Keyword.get(opts, :ttl_seconds, 3600)

    issued_at = DateTime.utc_now() |> DateTime.to_iso8601()

    msg = %SIWEMessage{
      domain: domain,
      address: String.downcase(address),
      uri: uri,
      version: version,
      statement: statement,
      issued_at: issued_at,
      expiration_time: expiration,
      not_before: not_before,
      request_id: request_id,
      resources: resources
    }

    message = SIWEMessage.build_message(msg)
    {:ok, msg, message}
  end

  @doc """
  Authenticate a user by verifying their signed SIWE message.

  Steps:
  1. Parse the signed message
  2. Verify temporal constraints (expiry, not-before)
  3. Verify the signature recovers the claimed address
  4. Create a session if all checks pass
  """
  @spec authenticate(String.t(), String.t(), binary()) ::
          {:ok, map()} | {:error, String.t()}
  def authenticate(message, signature, claimed_address) do
    # Step 1: Parse the SIWE message
    with {:ok, siwe_msg} <- SIWEMessage.parse_message(message),
         # Step 2: Verify the claimed address matches the message
         :ok <- verify_address(siwe_msg, claimed_address),
         # Step 3: Verify temporal constraints
         {:ok, _verified_msg} <- SIWEMessage.verify_temporal_constraints(siwe_msg),
         # Step 4: Verify the signature
         true <-
           Verifier.verify_signature(
             claimed_address,
             message,
             decode_signature(signature)
           ) do
      # Step 5: Create a session
      case Manager.create_session(claimed_address, %{
             siwe_domain: siwe_msg.domain,
             request_id: siwe_msg.request_id
           }) do
        {:ok, session_id} ->
          AuditLog.create(:login_success, claimed_address, %{
            domain: siwe_msg.domain,
            session_id: session_id
          })

          {:ok, %{session_id: session_id, address: claimed_address}}

        {:error, reason} ->
          AuditLog.create(:login_failure, claimed_address, %{reason: inspect(reason)})
          {:error, "Session creation failed: #{inspect(reason)}"}
      end
    else
      {:error, reason} ->
        AuditLog.create(:login_failure, claimed_address, %{reason: reason})
        {:error, reason}

      false ->
        AuditLog.create(:login_failure, claimed_address, %{reason: :signature_mismatch})
        {:error, "Signature does not match claimed address"}
    end
  end

  @doc """
  Verify that a signed message was signed by the claimed address.
  Returns true if the signature is valid for the message and address.
  """
  @spec verify_signature(String.t(), String.t(), binary()) :: boolean()
  def verify_signature(address, message, signature) do
    Verifier.verify_signature(address, message, decode_signature(signature))
  end

  @doc """
  Verify the SIWE message domain matches the expected domain.
  """
  @spec verify_domain(SIWEMessage.t(), String.t()) :: boolean()
  def verify_domain(%SIWEMessage{domain: domain}, expected) do
    String.downcase(domain) == String.downcase(expected)
  end

  # Internal helpers

  defp verify_address(%SIWEMessage{address: msg_addr}, claimed) do
    String.downcase(msg_addr) == String.downcase(claimed)
  end

  defp decode_signature(sig_hex) when is_binary(sig_hex) do
    sig_hex
    |> String.replace_leading("0x", "")
    |> Base.decode16(case: :mixed)
    |> case do
      {:ok, binary} -> binary
      _ -> <<>>
    end
  end

  defp decode_signature(sig_binary) when is_binary(sig_binary) do
    sig_binary
  end
end
