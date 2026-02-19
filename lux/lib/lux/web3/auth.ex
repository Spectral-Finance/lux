defmodule Lux.Web3.Auth do
  @moduledoc """
  Web3 Authentication and Authorization Framework for Lux.

  Provides a comprehensive authentication and authorization system for Web3
  applications, implementing:

  - **EIP-4361 (SIWE)** - Sign-In with Ethereum standard
  - **Signature Verification** - EIP-191 personal_sign and EIP-712 typed data
  - **Multi-Signature** - M-of-N threshold signature authentication
  - **Session Management** - ETS-backed sessions with TTL and refresh
  - **RBAC** - Role-based access control with hierarchical permissions
  - **Token Gating** - Access control based on token ownership
  - **Audit Logging** - Immutable event log for security events
  - **Multi-Chain** - Support for Ethereum, Polygon, Arbitrum, etc.

  ## Quick Start

      # 1. Start the auth services (or add to your supervision tree)
      Lux.Web3.Auth.child_specs()

      # 2. Authenticate a user with SIWE
      {:ok, session} = Lux.Web3.Auth.authenticate_siwe(%{
        message: siwe_message_string,
        signature: "0x...",
        address: "0x71C7..."
      })

      # 3. Check permissions
      true = Lux.Web3.Auth.authorized?(session.token, "agents:read")

  ## Architecture

  The framework is composed of several independent modules that can be
  used together or separately:

  - `Lux.Web3.Auth.SIWEMessage` - EIP-4361 message handling
  - `Lux.Web3.Auth.SignatureVerifier` - Cryptographic signature verification
  - `Lux.Web3.Auth.Session` - Session lifecycle management
  - `Lux.Web3.Auth.RBAC` - Role and permission management
  - `Lux.Web3.Auth.TokenGate` - Token-gated access control
  - `Lux.Web3.Auth.MultiSig` - Multi-signature authentication
  - `Lux.Web3.Auth.AuditLog` - Security event logging
  """

  alias Lux.Web3.Auth.AuditLog
  alias Lux.Web3.Auth.RBAC
  alias Lux.Web3.Auth.Session
  alias Lux.Web3.Auth.SIWEMessage
  alias Lux.Web3.Auth.SignatureVerifier

  require Logger

  @supported_chains %{
    1 => "Ethereum Mainnet",
    5 => "Goerli Testnet",
    10 => "Optimism",
    56 => "BNB Smart Chain",
    100 => "Gnosis Chain",
    137 => "Polygon",
    8453 => "Base",
    42_161 => "Arbitrum One",
    43_114 => "Avalanche C-Chain",
    11_155_111 => "Sepolia Testnet"
  }

  @doc """
  Returns child specs for all auth services, suitable for a Supervisor.

  ## Usage

      children = Lux.Web3.Auth.child_specs()
      Supervisor.start_link(children, strategy: :one_for_one)
  """
  @spec child_specs(keyword()) :: [Supervisor.child_spec()]
  def child_specs(opts \\ []) do
    [
      {Session, Keyword.get(opts, :session, [])},
      {RBAC, Keyword.get(opts, :rbac, [])},
      {AuditLog, Keyword.get(opts, :audit_log, [])}
    ]
  end

  @doc """
  Authenticates a user using a SIWE (EIP-4361) signed message.

  This is the primary authentication entry point. It:
  1. Parses and validates the SIWE message
  2. Verifies the signature against the claimed address
  3. Creates an authenticated session
  4. Logs the authentication event

  ## Parameters

    * `params` - Map with:
      * `:message` - The SIWE message string
      * `:signature` - The hex-encoded signature
      * `:address` - The expected signer address
      * `:session_ttl` - Session TTL in seconds (optional, defaults to 3600)

  ## Returns

    * `{:ok, session}` with the created session on success
    * `{:error, reason}` on failure
  """
  @spec authenticate_siwe(map()) :: {:ok, Session.session_data()} | {:error, String.t()}
  def authenticate_siwe(params) do
    with {:ok, message} <- SIWEMessage.parse(params.message),
         :ok <- SIWEMessage.validate(message),
         {:ok, true} <-
           SignatureVerifier.verify_signature(
             params.message,
             params.signature,
             params.address
           ),
         :ok <- verify_address_match(message.address, params.address),
         {:ok, session} <-
           Session.create(%{
             address: params.address,
             chain_id: message.chain_id,
             ttl: Map.get(params, :session_ttl, 3600),
             metadata: %{
               domain: message.domain,
               statement: message.statement,
               nonce: message.nonce
             }
           }) do
      AuditLog.log(:auth_success, params.address, %{
        chain_id: message.chain_id,
        domain: message.domain,
        method: :siwe
      })

      {:ok, session}
    else
      {:ok, false} ->
        AuditLog.log(:auth_failure, params.address, %{reason: "signature mismatch"})
        {:error, "signature does not match address"}

      {:error, reason} = error ->
        AuditLog.log(:auth_failure, Map.get(params, :address, "unknown"), %{
          reason: to_string(reason)
        })

        error
    end
  end

  @doc """
  Checks if a session token is authorized for a specific permission.

  ## Parameters

    * `token` - The session token
    * `permission` - The permission string ("resource:action")

  ## Returns

    * `true` if authorized
    * `false` otherwise
  """
  @spec authorized?(String.t(), String.t()) :: boolean()
  def authorized?(token, permission) do
    case Session.get(token) do
      {:ok, session} ->
        has_perm = RBAC.has_permission?(session.address, permission)

        if has_perm do
          AuditLog.log(:permission_granted, session.address, %{permission: permission})
        else
          AuditLog.log(:permission_denied, session.address, %{permission: permission})
        end

        has_perm

      {:error, _} ->
        false
    end
  end

  @doc """
  Validates and returns session data if the token is valid.
  """
  @spec validate_session(String.t()) :: {:ok, Session.session_data()} | {:error, atom()}
  def validate_session(token) do
    Session.get(token)
  end

  @doc """
  Returns a map of supported chain IDs and their names.
  """
  @spec supported_chains() :: %{pos_integer() => String.t()}
  def supported_chains, do: @supported_chains

  @doc """
  Checks if a chain ID is supported.
  """
  @spec chain_supported?(pos_integer()) :: boolean()
  def chain_supported?(chain_id), do: Map.has_key?(@supported_chains, chain_id)

  # Private helpers

  defp verify_address_match(msg_address, expected_address) do
    if String.downcase(msg_address) == String.downcase(expected_address) do
      :ok
    else
      {:error, "SIWE message address does not match expected address"}
    end
  end
end
