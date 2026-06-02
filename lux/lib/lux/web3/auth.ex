defmodule Lux.Web3.Auth do
  @moduledoc """
  Web3 Authentication and Authorization Framework.

  Provides comprehensive Web3 authentication supporting:
  - Sign-In with Ethereum (EIP-4361)
  - Multi-chain signature verification
  - Role-Based Access Control (RBAC)
  - Token-gated access control
  - Session management
  - Audit logging

  ## Quick Start

      # Authenticate with SIWE message and signature
      {:ok, session} = Lux.Web3.Auth.authenticate(siwe_message, signature)

      # Verify if an address has a specific permission
      if Lux.Web3.Auth.has_permission?(address, :execute_trades) do
        # Allow trading
      end

      # Check token-gated access
      {:ok, true} = Lux.Web3.Auth.check_token_gate(address, gate_rules)

  ## Architecture

  The framework consists of several sub-modules:
  - `Lux.Web3.Auth.SIWE` — EIP-4361 message construction and parsing
  - `Lux.Web3.Auth.Verifier` — Cryptographic signature verification
  - `Lux.Web3.Auth.Session` — Session lifecycle management
  - `Lux.Web3.Auth.RBAC` — Role-based access control
  - `Lux.Web3.Auth.TokenGating` — Token ownership verification
  - `Lux.Web3.Auth.AuditLog` — Security event logging
  """

  require Logger

  alias Lux.Web3.Auth.{SIWE, Verifier, Session, RBAC, TokenGating, AuditLog}

  @doc """
  Starts the Web3 Auth subsystem including all ETS stores.
  """
  @spec start() :: :ok
  def start do
    Session.init_store()
    RBAC.init_store()
    AuditLog.init_store()
    Logger.info("Web3 Auth framework initialized")
    :ok
  end

  @doc """
  Authenticates a user with a SIWE message and its signature.

  Returns `{:ok, session}` on success or `{:error, reason}` on failure.
  """
  @spec authenticate(SIWE.t(), String.t(), keyword()) ::
          {:ok, Session.t()} | {:error, String.t()}
  def authenticate(%SIWE{} = siwe, signature, opts \\ []) do
    with {:ok, address} <- Verifier.verify_siwe(siwe, signature),
         {:ok, session} <- Session.create(address, opts) do
      AuditLog.log_auth_success(address, %{
        chain_id: siwe.chain_id,
        session_id: session.session_id
      })

      AuditLog.log_session_created(address, session.session_id)
      {:ok, session}
    else
      {:error, reason} ->
        address = siwe.address
        AuditLog.log_auth_failure(address, reason)
        {:error, reason}
    end
  end

  @doc """
  Verifies a session ID is valid and not expired.
  """
  @spec verify_session(String.t()) :: {:ok, Session.t()} | {:error, atom()}
  def verify_session(session_id) do
    Session.get(session_id)
  end

  @doc """
  Refreshes a session's expiration.
  """
  @spec refresh_session(String.t(), pos_integer()) :: {:ok, Session.t()} | {:error, atom()}
  def refresh_session(session_id, ttl \\ nil) do
    Session.refresh(session_id, ttl)
  end

  @doc """
  Invalidates a session.
  """
  @spec logout(String.t()) :: :ok
  def logout(session_id) do
    case Session.get(session_id) do
      {:ok, session} ->
        AuditLog.log_session_expired(session.address, session_id)
        Session.delete(session_id)

      {:error, _} ->
        Session.delete(session_id)
    end

    :ok
  end

  @doc """
  Checks if an address has a specific permission.
  """
  @spec has_permission?(String.t(), atom() | String.t()) :: boolean()
  def has_permission?(address, permission) do
    RBAC.has_permission?(address, permission)
  end

  @doc """
  Checks if an address has a specific role.
  """
  @spec has_role?(String.t(), atom() | String.t()) :: boolean()
  def has_role?(address, role) do
    RBAC.has_role?(address, role)
  end

  @doc """
  Grants a role to an address.
  """
  @spec grant_role(String.t(), String.t(), atom() | String.t(), String.t() | nil) ::
          :ok | {:error, String.t()}
  def grant_role(actor_address, target_address, role, scope \\ nil) do
    result = RBAC.assign_role(target_address, role, scope)

    with :ok <- result do
      AuditLog.log_role_change(actor_address, target_address, role, :assigned)
    end

    result
  end

  @doc """
  Revokes a role from an address.
  """
  @spec revoke_role(String.t(), String.t(), atom() | String.t(), String.t() | nil) :: :ok
  def revoke_role(actor_address, target_address, role, scope \\ nil) do
    RBAC.revoke_role(target_address, role, scope)
    AuditLog.log_role_change(actor_address, target_address, role, :revoked)
    :ok
  end

  @doc """
  Assigns multiple roles to an address.
  """
  @spec grant_roles(String.t(), String.t(), [atom() | String.t()]) ::
          :ok | {:error, String.t()}
  def grant_roles(actor_address, target_address, roles) do
    results =
      Enum.map(roles, fn role ->
        case RBAC.assign_role(target_address, role) do
          :ok ->
            AuditLog.log_role_change(actor_address, target_address, role, :assigned)
            :ok

          error ->
            error
        end
      end)

    case Enum.find(results, fn r -> r != :ok end) do
      nil -> :ok
      error -> error
    end
  end

  @doc """
  Checks token-gated access for an address against a list of rules.
  """
  @spec check_token_gate(String.t(), [TokenGating.gate_rule()], keyword()) ::
          TokenGating.gate_result()
  def check_token_gate(address, gates, opts \\ []) do
    mode = Keyword.get(opts, :mode, :and)
    threshold = Keyword.get(opts, :threshold, 1)

    result =
      case mode do
        :and -> TokenGating.check_gates_and(address, gates, opts)
        :or -> TokenGating.check_gates_or(address, gates, opts)
        :threshold -> TokenGating.check_gates_threshold(address, gates, threshold, opts)
      end

    case result do
      {:ok, passed} ->
        AuditLog.log_signature_verification(address, passed, %{
          gate_count: length(gates),
          mode: mode
        })

        result

      error ->
        result
    end
  end

  @doc """
  Retrieves the audit log for a specific address.
  """
  @spec get_audit_log(String.t(), keyword()) :: [AuditLog.entry()]
  def get_audit_log(address, opts \\ []) do
    AuditLog.query_by_address(address, opts)
  end

  @doc """
  Returns all effective permissions for an address.
  """
  @spec get_permissions(String.t()) :: [String.t()]
  def get_permissions(address) do
    RBAC.get_permissions(address)
  end

  @doc """
  Returns all active sessions for an address.
  """
  @spec get_sessions(String.t()) :: [Session.t()]
  def get_sessions(address) do
    Session.get_by_address(address)
  end

  @doc """
  Invalidates all sessions for an address.
  """
  @spec logout_all(String.t()) :: :ok
  def logout_all(address) do
    Session.delete_all(address)
    :ok
  end
end
