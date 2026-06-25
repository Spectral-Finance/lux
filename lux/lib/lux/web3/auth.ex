defmodule Lux.Web3.Auth do
  @moduledoc """
  Web3 Authentication and Authorization Framework

  Comprehensive EIP-4361 (SIWE) compliant authentication system with:
  - Sign-in with Ethereum (EIP-4361)
  - Multi-signature support
  - Role-based access control
  - Permission management
  - Session management
  - Signature verification
  - Token gating
  - Audit logging

  ## Quick Start

      # Generate a login challenge
      {:ok, msg, message} = Lux.Web3.Auth.challenge(address, domain)

      # Client signs the message with their wallet
      # Server receives the signature and verifies
      {:ok, session} = Lux.Web3.Auth.authenticate(message, signature, address)

      # Check token-gated access
      {:ok, allowed} = Lux.Web3.Auth.check_token_gate(address, gate_config)

      # Verify a signature
      true = Lux.Web3.Auth.verify_signature(address, message, signature)

  ## Architecture

  This module provides a unified interface to the sub-components:
  - SIWE authentication flow
  - Session management (via Lux.Web3.Session.Manager)
  - Signature verification (via Lux.Web3.Signature.Verifier)
  - Token gating (via Lux.Web3.Auth.TokenGate)
  - Multi-sig approvals (via Lux.Web3.Multisig.Approval)
  - RBAC (via Lux.Web3.Schemas.RolePermission)
  - Audit logging (via Lux.Web3.Schemas.AuditLog)
  """

  alias Lux.Web3.Auth.SIWE
  alias Lux.Web3.Session.Manager
  alias Lux.Web3.Signature.Verifier
  alias Lux.Web3.Auth.TokenGate
  alias Lux.Web3.Multisig.Approval
  alias Lux.Web3.Schemas.RolePermission
  alias Lux.Web3.Schemas.AuditLog
  alias Lux.Web3.Schemas.SIWEMessage

  @version "0.5.0"
  @doc """
  Return the framework version.
  """
  @spec version() :: String.t()
  def version, do: @version

  @doc """
  Generate a SIWE challenge for authentication.
  Delegates to Lux.Web3.Auth.SIWE.challenge/3.
  """
  @spec challenge(String.t(), String.t(), keyword()) ::
          {:ok, SIWEMessage.t(), String.t()} | {:error, term()}
  def challenge(address, domain, opts \ []) do
    SIWE.challenge(address, domain, opts)
  end

  @doc """
  Authenticate a user with their signed SIWE message.
  Delegates to Lux.Web3.Auth.SIWE.authenticate/3.
  """
  @spec authenticate(String.t(), String.t(), binary()) ::
          {:ok, map()} | {:error, String.t()}
  def authenticate(message, signature, claimed_address) do
    SIWE.authenticate(message, signature, claimed_address)
  end

  @doc """
  Verify a signature recovers the claimed address.
  Delegates to Lux.Web3.Signature.Verifier.verify_signature/3.
  """
  @spec verify_signature(String.t(), binary(), binary()) :: boolean()
  def verify_signature(address, message, signature) do
    Verifier.verify_signature(address, message, signature)
  end

  @doc """
  Recover the signer address from a signature.
  Delegates to Lux.Web3.Signature.Verifier.recover_address/2.
  """
  @spec recover_address(binary(), binary()) :: {:ok, String.t()} | {:error, term()}
  def recover_address(message, signature) do
    Verifier.recover_address(message, signature)
  end

  @doc """
  Check token-gated access for an address.
  Delegates to Lux.Web3.Auth.TokenGate.evaluate/2.
  """
  @spec check_token_gate(String.t(), TokenGate.gate_config()) ::
          {:ok, boolean()} | {:error, term()}
  def check_token_gate(address, gate_config) do
    TokenGate.evaluate(address, gate_config)
  end

  @doc """
  Create a multi-sig proposal.
  Delegates to Lux.Web3.Multisig.Approval.create_proposal/5.
  """
  @spec create_multisig_proposal(
          Approval.config(),
          String.t(),
          String.t(),
          binary(),
          non_neg_integer()
        ) ::
          {:ok, Approval.proposal()} | {:error, String.t()}
  def create_multisig_proposal(config, proposer, target, data, value \ 0) do
    Approval.create_proposal(config, proposer, target, data, value)
  end

  @doc """
  Approve a multi-sig proposal.
  Delegates to Lux.Web3.Multisig.Approval.approve/3.
  """
  @spec approve_multisig(Approval.proposal(), String.t(), binary()) ::
          {:ok, Approval.proposal()} | {:error, String.t()}
  def approve_multisig(proposal, address, signature) do
    Approval.approve(proposal, address, signature)
  end

  @doc """
  Create a new session for an address.
  Delegates to Lux.Web3.Session.Manager.create_session/2.
  """
  @spec create_session(String.t(), map()) :: {:ok, String.t()} | {:error, term()}
  def create_session(address, metadata \ %{}) do
    Manager.create_session(address, metadata)
  end

  @doc """
  Revoke a session by ID.
  Delegates to Lux.Web3.Session.Manager.revoke_session/1.
  """
  @spec revoke_session(String.t()) :: :ok | {:error, :not_found}
  def revoke_session(session_id) do
    Manager.revoke_session(session_id)
  end

  @doc """
  Check if a session is valid.
  """
  @spec session_valid?(String.t()) :: boolean()
  def session_valid?(session_id) do
    Manager.is_session_valid?(session_id)
  end

  @doc """
  Get all active sessions for an address.
  """
  @spec get_sessions(String.t()) :: [map()]
  def get_sessions(address) do
    Manager.get_sessions(address)
  end

  @doc """
  Create a new RBAC schema.
  """
  @spec new_rbac() :: RolePermission.t()
  def new_rbac do
    RolePermission.new()
  end

  @doc """
  Add a role to the RBAC schema.
  """
  @spec add_role(RolePermission.t(), RolePermission.role()) :: RolePermission.t()
  def add_role(schema, role) do
    RolePermission.add_role(schema, role)
  end

  @doc """
  Assign a role to an address.
  """
  @spec assign_role(RolePermission.t(), String.t(), String.t()) :: RolePermission.t()
  def assign_role(schema, address, role_name) do
    RolePermission.assign_role(schema, address, role_name)
  end

  @doc """
  Revoke a role from an address.
  """
  @spec revoke_role(RolePermission.t(), String.t(), String.t()) :: RolePermission.t()
  def revoke_role(schema, address, role_name) do
    RolePermission.revoke_role(schema, address, role_name)
  end

  @doc """
  Check if an address has a permission.
  """
  @spec has_permission?(RolePermission.t(), String.t(), RolePermission.permission()) :: boolean()
  def has_permission?(schema, address, permission) do
    RolePermission.has_permission?(schema, address, permission)
  end

  @doc """
  Log an authentication event.
  """
  @spec log_event(AuditLog.action(), String.t(), map()) :: AuditLog.t()
  def log_event(action, address, details \ %{}) do
    AuditLog.create(action, address, details)
  end

  @doc """
  Hash a message for EIP-191 personal_sign.
  """
  @spec hash_personal_message(binary()) :: binary()
  def hash_personal_message(message) do
    Verifier.hash_personal_message(message)
  end

  @doc """
  Hash typed data for EIP-712.
  """
  @spec hash_typed_data(binary()) :: binary()
  def hash_typed_data(data) do
    Verifier.hash_typed_data(data)
  end

  @doc """
  Sign a message with a private key (for testing/demo purposes).
  """
  @spec sign_message(binary(), binary()) :: {:ok, binary()} | {:error, term()}
  def sign_message(private_key, message) do
    Verifier.sign_message(private_key, message)
  end
end
