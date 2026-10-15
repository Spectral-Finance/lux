defmodule Lux.Web3.Auth do
  @moduledoc """
  Unified Web3 Authentication and Authorization Framework for Lux agents.

  Coordinates:
  - Sign-In with Ethereum (`Lux.Web3.Auth.SIWE` / EIP-4361) challenge generation and validation
  - Cryptographic signature verification (`Lux.Web3.Auth.Signature` / EIP-191 & M-of-N multisig)
  - Role-Based Access Control (`Lux.Web3.Auth.RBAC`)
  - Token-gated access control (`Lux.Web3.Auth.TokenGate`)
  - Session creation, verification, revocation, and audit logging (`Lux.Web3.Auth.AuditLog`)
  """

  alias Lux.Web3.Auth.AuditLog
  alias Lux.Web3.Auth.RBAC
  alias Lux.Web3.Auth.Signature
  alias Lux.Web3.Auth.SIWE
  alias Lux.Web3.Auth.TokenGate

  @sessions_table :lux_web3_auth_sessions
  @nonces_table :lux_web3_auth_nonces
  @default_ttl_seconds 3_600

  @doc """
  Initializes ETS tables for sessions, nonces, RBAC, and audit logs.
  """
  @spec ensure_started() :: :ok
  def ensure_started do
    ensure_table(@sessions_table)
    ensure_table(@nonces_table)
    RBAC.ensure_started()
    AuditLog.ensure_started()
    :ok
  end

  @doc """
  Resets all authentication sessions, nonces, RBAC assignments, and audit logs.
  """
  @spec reset!() :: :ok
  def reset! do
    ensure_started()
    :ets.delete_all_objects(@sessions_table)
    :ets.delete_all_objects(@nonces_table)
    RBAC.reset!()
    AuditLog.reset!()
    :ok
  end

  @doc """
  Creates a SIWE challenge message and registers its nonce for replay protection.
  """
  @spec create_challenge(map() | keyword()) ::
          {:ok, %{message: String.t(), siwe: SIWE.t(), nonce: String.t()}}
          | {:error, term()}
  def create_challenge(attrs) do
    ensure_started()

    with {:ok, siwe} <- SIWE.build(attrs) do
      raw = SIWE.format(siwe)
      :ets.insert(@nonces_table, {siwe.nonce, :pending})
      AuditLog.record(:challenge_created, siwe.address, %{nonce: siwe.nonce})
      {:ok, %{message: raw, siwe: siwe, nonce: siwe.nonce}}
    end
  end

  @doc """
  Verifies a signed SIWE message, consumes its nonce, and issues an active session.
  """
  @spec authenticate_siwe(String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, atom()}
  def authenticate_siwe(raw_message, signature_hex, opts \\ [])
      when is_binary(raw_message) and is_binary(signature_hex) do
    ensure_started()

    with {:ok, siwe} <- SIWE.parse(raw_message),
         :ok <- verify_nonce_not_used(siwe.nonce),
         :ok <- SIWE.validate(siwe, opts),
         true <- Signature.verify_signature(raw_message, signature_hex, siwe.address) do
      :ets.insert(@nonces_table, {siwe.nonce, :used})
      session = create_session_entry(siwe, opts)
      AuditLog.record(:siwe_authenticated, siwe.address, %{session_token: session.token})
      {:ok, session}
    else
      false ->
        AuditLog.record(:siwe_failed, nil, %{reason: :invalid_signature})
        {:error, :invalid_signature}

      {:error, reason} = err ->
        AuditLog.record(:siwe_failed, nil, %{reason: reason})
        err
    end
  end

  @doc """
  Verifies an active session token and checks whether it has expired.
  """
  @spec verify_session(String.t(), keyword()) :: {:ok, map()} | {:error, atom()}
  def verify_session(token, opts \\ []) when is_binary(token) do
    ensure_started()
    now = Keyword.get(opts, :now, DateTime.utc_now())

    case :ets.lookup(@sessions_table, token) do
      [{^token, session}] ->
        if DateTime.compare(now, session.expires_at) == :gt do
          :ets.delete(@sessions_table, token)
          {:error, :session_expired}
        else
          roles = RBAC.get_roles(session.address)
          {:ok, Map.put(session, :roles, roles)}
        end

      [] ->
        {:error, :session_not_found}
    end
  end

  @doc """
  Revokes an active session token.
  """
  @spec revoke_session(String.t()) :: :ok
  def revoke_session(token) when is_binary(token) do
    ensure_started()

    case :ets.lookup(@sessions_table, token) do
      [{^token, session}] ->
        :ets.delete(@sessions_table, token)
        AuditLog.record(:session_revoked, session.address, %{session_token: token})
        :ok

      [] ->
        :ok
    end
  end

  @doc """
  Authorizes an Ethereum address against a required permission and optional token-gate rule.
  """
  @spec authorize(String.t(), atom(), keyword()) :: {:ok, map()} | {:error, term()}
  def authorize(address, permission, opts \\ [])
      when is_binary(address) and is_atom(permission) do
    ensure_started()

    if RBAC.has_permission?(address, permission) do
      check_optional_token_gate(address, permission, opts)
    else
      AuditLog.record(:authorization_denied, address, %{
        permission: permission,
        reason: :insufficient_permissions
      })

      {:error, :insufficient_permissions}
    end
  end

  defp check_optional_token_gate(address, permission, opts) do
    case Keyword.get(opts, :token_gate) do
      nil ->
        AuditLog.record(:authorization_granted, address, %{permission: permission})
        {:ok, %{authorized: true, address: String.downcase(address), permission: permission}}

      rule when is_map(rule) ->
        case TokenGate.check_access(address, rule, opts) do
          {:ok, %{granted: true} = gate_res} ->
            AuditLog.record(:authorization_granted, address, %{
              permission: permission,
              token_gate: gate_res
            })

            {:ok, Map.merge(gate_res, %{authorized: true, permission: permission})}

          {:ok, %{granted: false} = gate_res} ->
            AuditLog.record(:authorization_denied, address, %{
              permission: permission,
              reason: :token_gate_failed,
              token_gate: gate_res
            })

            {:error, :token_gate_failed}

          {:error, _reason} = err ->
            err
        end
    end
  end

  defp verify_nonce_not_used(nonce) do
    case :ets.lookup(@nonces_table, nonce) do
      [{^nonce, :used}] -> {:error, :nonce_already_used}
      _ -> :ok
    end
  end

  defp create_session_entry(siwe, opts) do
    now = Keyword.get(opts, :now, DateTime.utc_now())
    ttl = Keyword.get(opts, :ttl_seconds, @default_ttl_seconds)
    token = "lux_sess_" <> Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
    addr = String.downcase(siwe.address)

    session = %{
      token: token,
      address: addr,
      chain_id: siwe.chain_id,
      domain: siwe.domain,
      nonce: siwe.nonce,
      issued_at: now,
      expires_at: DateTime.add(now, ttl, :second),
      roles: RBAC.get_roles(addr)
    }

    :ets.insert(@sessions_table, {token, session})
    session
  end

  defp ensure_table(name) do
    case :ets.whereis(name) do
      :undefined ->
        try do
          :ets.new(name, [:named_table, :public, :set, read_concurrency: true])
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end
  end
end
