defmodule LuxApp.Contexts.Web3Auth do
  @moduledoc """
  Web3 Authentication Context - EIP-4361 SIWE, RBAC, token gating.
  """
  import Ecto.Query, warn: false
  alias LuxApp.Repo
  alias LuxApp.Schemas.{Web3AuthSession, Permission, RoleAssignment, AuthAuditLog}
  @default_domain "lux.spectral.finance"
  @default_chain_id 1
  @session_ttl_days 7

  @spec issue_challenge(String.t(), keyword()) :: {:ok, Web3AuthSession.t()} | {:error, Ecto.Changeset.t()}
  def issue_challenge(wallet_address, opts \ []) do
    domain = Keyword.get(opts, :domain, @default_domain)
    chain_id = Keyword.get(opts, :chain_id, @default_chain_id)
    statement = Keyword.get(opts, :statement)
    expiry = Keyword.get(opts, :expiry_days, @session_ttl_days)
    nonce = generate_nonce()
    issued_at = DateTime.utc_now()
    expires_at = DateTime.add(issued_at, expiry * 86400, :second)
    %Web3AuthSession{}
    |> Web3AuthSession.changeset(%{wallet_address: normalize_address(wallet_address), chain_id: chain_id, nonce: nonce, domain: domain, statement: statement, issued_at: issued_at, expires_at: expires_at, signature: ""})
    |> Repo.insert()
    |> case do
      {:ok, session} -> audit_log(session.wallet_address, "challenge_issued", %{domain: domain, chain_id: chain_id}); {:ok, session}
      {:error, cs} -> {:error, cs}
    end
  end

  @spec verify_signature(String.t(), String.t(), keyword()) :: {:ok, Web3AuthSession.t()} | {:error, String.t()}
  def verify_signature(session_id, signature, opts \ []) do
    session = Repo.get(Web3AuthSession, session_id)
    with %Web3AuthSession{} <- session, nil <- session.revoked_at, true <- valid_session?(session), {:ok, recovered} <- recover_signer(session, signature) do
      wallet = normalize_address(session.wallet_address)
      if String.downcase(recovered) == String.downcase(wallet) do
        session |> Ecto.Changeset.change(signature: signature) |> Repo.update()
        |> case do
          {:ok, u} ->
            roles = resolve_roles(wallet); perms = resolve_permissions(roles)
            u |> Ecto.Changeset.change(roles: roles, permissions: perms) |> Repo.update()
            |> case do
              {:ok, f} -> audit_log(wallet, "authentication_success", %{roles: roles}); {:ok, f}
              {:error, _} -> {:error, "Failed to update session"}
            end
          {:error, _} -> {:error, "Failed to update session with signature"}
        end
      else
        audit_log(wallet, "signature_mismatch", %{expected: wallet, recovered: recovered}); {:error, "Signature mismatch"}
      end
    else
      nil -> {:error, "Session not found"}
      false -> {:error, "Session expired or revoked"}
      {:error, r} -> audit_log(session.wallet_address, "signature_error", %{error: inspect(r)}); {:error, "Invalid signature: " <> inspect(r)}
    end
  end

  @spec has_permission?(String.t(), String.t(), String.t()) :: boolean()
  def has_permission?(wa, resource, action) do
    roles = resolve_roles(normalize_address(wa)); perms = resolve_permissions(roles)
    Enum.any?(perms, fn p -> Map.get(p, "resource") == resource and Map.get(p, "action") == action end)
  end

  @spec revoke_session(String.t()) :: {:ok, Web3AuthSession.t()} | {:error, term()}
  def revoke_session(sid) do
    case Repo.get(Web3AuthSession, sid) do
      %Web3AuthSession{} = s when is_nil(s.revoked_at) ->
        s |> Ecto.Changeset.change(%{revoked_at: DateTime.utc_now()}) |> Repo.update()
        |> case do
          {:ok, r} -> audit_log(r.wallet_address, "session_revoked", %{session_id: sid}); {:ok, r}
          {:error, _} -> {:error, :update_failed}
        end
      %Web3AuthSession{} -> {:error, :already_revoked}
      nil -> {:error, :not_found}
    end
  end

  @spec revoke_all_sessions(String.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def revoke_all_sessions(wa) do
    wallet = normalize_address(wa)
    q = from s in Web3AuthSession, where: s.wallet_address == ^wallet and is_nil(s.revoked_at), update: [set: [revoked_at: ^DateTime.utc_now()]]
    {count, _} = Repo.update_all(q, [])
    audit_log(wallet, "all_sessions_revoked", %{count: count}); {:ok, count}
  end

  @spec assign_role(String.t(), String.t(), String.t(), keyword()) :: {:ok, RoleAssignment.t()} | {:error, Ecto.Changeset.t()}
  def assign_role(wa, role, by, opts \ []) do
    ea = case Keyword.fetch(opts, :expires_at) do; {:ok, d} -> d; :error -> nil end
    %RoleAssignment{} |> RoleAssignment.changeset(%{wallet_address: normalize_address(wa), role: role, granted_by: by, expires_at: ea}) |> Repo.insert()
    |> case do
      {:ok, a} -> audit_log(a.wallet_address, "role_assigned", %{role: role, granted_by: by}); {:ok, a}
      {:error, cs} -> {:error, cs}
    end
  end

  @spec remove_role(String.t(), String.t()) :: {:ok, true} | {:error, term()}
  def remove_role(wa, role) do
    wallet = normalize_address(wa)
    q = from r in RoleAssignment, where: r.wallet_address == ^wallet and r.role == ^role
    case Repo.delete_all(q) do; {0, _} -> {:error, :not_found}; {_c, _} -> audit_log(wallet, "role_removed", %{role: role}); {:ok, true} end
  end

  @spec list_roles(String.t()) :: [RoleAssignment.t()]
  def list_roles(wa) do
    wallet = normalize_address(wa)
    RoleAssignment |> where([r], r.wallet_address == ^wallet) |> maybe_filter_expired() |> Repo.all()
  end

  @spec resolve_roles(String.t()) :: [String.t()]
  def resolve_roles(wa) do
    wallet = normalize_address(wa)
    RoleAssignment |> where([r], r.wallet_address == ^wallet) |> maybe_filter_expired() |> select([r], r.role) |> Repo.all()
  end

  @spec resolve_permissions([String.t()]) :: [map()]
  def resolve_permissions(roles) do
    query = from p in Permission, where: p.role in ^roles, select: %{resource: p.resource, action: p.action, role: p.role, name: p.name}
    Repo.all(query)
  end

  @spec has_role?(String.t(), String.t()) :: boolean()
  def has_role?(wa, role) do
    wallet = normalize_address(wa)
    RoleAssignment |> where([r], r.wallet_address == ^wallet and r.role == ^role) |> maybe_filter_expired() |> Repo.exists?()
  end

  @spec valid_session?(Web3AuthSession.t()) :: boolean()
  def valid_session?(%Web3AuthSession{expires_at: ea, revoked_at: ra}), do: is_nil(ra) and DateTime.after?(ea, DateTime.utc_now())

  @spec verify_token_gate(String.t(), map(), keyword()) :: {:ok, boolean()} | {:error, String.t()}
  def verify_token_gate(wa, cond, opts \ []) do
    wallet = normalize_address(wa)
    if Keyword.get(opts, :dry_run, false) do; {:ok, true}
    else
      cid = Map.get(cond, :chain_id, @default_chain_id); ctr = Map.get(cond, :contract_address); thr = Map.get(cond, :threshold); dec = Map.get(cond, :decimals, 18)
      unless ctr and thr do; {:error, "Missing contract_address or threshold"}
      else
        case fetch_token_balance(wallet, cid, ctr, dec) do
          {:ok, bal} -> audit_log(wallet, "token_gate_check", %{chain_id: cid, contract: ctr, balance: bal, threshold: thr, allowed: bal >= thr}); {:ok, bal >= thr}
          {:error, r} -> {:error, "Failed to fetch token balance: " <> r}
        end
      end
    end
  end

  @spec check_token_gates(String.t(), [map()], keyword()) :: {:ok, boolean()} | {:error, String.t()}
  def check_token_gates(wa, conds, opts \ []) do
    wallet = normalize_address(wa)
    res = Enum.map(conds, fn c -> verify_token_gate(wallet, c, opts) end)
    case Enum.all?(res, &match?({:ok, true}, &1)) do
      true -> {:ok, true}
      false -> audit_log(wallet, "token_gate_failed", %{count: length(conds)}); {:ok, false}
    end
  end

  @spec list_audit_logs(map()) :: {:ok, [AuthAuditLog.t()]} | {:error, term()}
  def list_audit_logs(params \ %{}) do
    w = Map.get(params, :wallet_address); e = Map.get(params, :event)
    q = from a in AuthAuditLog
    q = if w, do: where(q, [a], a.wallet_address == ^w), else: q
    q = if e, do: where(q, [a], a.event == ^e), else: q
    {:ok, Repo.all(q)}
  end

  @spec format_siwe_message(Web3AuthSession.t()) :: String.t()
  def format_siwe_message(%Web3AuthSession{} = s) do
    base =
      """
      #{s.domain} wants you to sign in with your Ethereum account:
      #{s.wallet_address}

      URI: https://#{s.domain}
      Version: 1
      Chain ID: #{s.chain_id}
      nonce: #{s.nonce}
      Issued At: #{format_datetime(s.issued_at)}
      """
    exp = if s.expires_at, do: "Expiration Time: #{format_datetime(s.expires_at)}", else: ""
    stmt = if s.statement, do: "\n#{s.statement}\n", else: "\n"
    if exp != "", do: base <> stmt <> exp, else: base <> stmt
  end

  @spec format_datetime(DateTime.t()) :: String.t()
  def format_datetime(%DateTime{} = dt), do: dt |> NaiveDateTime.from_datetime!() |> NaiveDateTime.to_iso8601()

  @doc false
  @spec normalize_address(String.t()) :: String.t()
  def normalize_address(addr) do
    case String.downcase(String.trim(addr)) do
      <<"0x", h::binary>> -> "0x" <> pad_hex(h)
      <<_::binary>> -> "0x" <> pad_hex(addr)
    end
  end
  defp pad_hex(h) when byte_size(h) >= 40, do: String.slice(h, 0, 40)
  defp pad_hex(h), do: String.pad_leading(h, 40, "0")

  @doc false
  @spec generate_nonce() :: String.t()
  def generate_nonce(), do: :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)

  @doc false
  @spec recover_signer(Web3AuthSession.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def recover_signer(%Web3AuthSession{} = s, sig) do
    msg = format_siwe_message(s)
    mh = :crypto.hash(:sha256, "\x19Ethereum Signed Message:\n" <> Integer.to_string(String.length(msg)) <> msg)
    with {:ok, {r, sv, v}} <- decode_signature(sig), {:ok, pk} <- recover_public_key(mh, r, sv, v) do
      {:ok, pubkey_to_address(pk)}
    else
      {:error, r} -> {:error, r}
    end
  end
  defp decode_signature(sig) when is_binary(sig), do: sig |> String.trim() |> Base.decode16!(case: :mixed) |> extract_rs_v()
  defp decode_signature(_), do: {:error, "invalid_signature_format"}
  defp extract_rs_v(<<r::32-binary, s::32-binary, v::binary>>), do: {:ok, {r, s, :binary.decode_unsigned(v)}}
  defp extract_rs_v(_), do: {:error, "invalid_signature_length"}

  @doc false
  @spec pubkey_to_address(binary()) :: String.t()
  def pubkey_to_address(pk), do: "0x" <> Base.encode16(:crypto.hash(:keccak, pk) |> :crypto.hash(:sha256) |> String.slice(-20..-1), case: :lower)

    @doc false
  @spec recover_public_key(binary(), binary(), binary(), integer()) :: {:ok, binary()} | {:error, term()}
  def recover_public_key(mh, r, sv, v) do
    with {:ok, sig} <- ExSecp256k1.Signature.from_compact(r, sv),
         {:ok, pk} <- ExSecp256k1.PublicKey.recover(sig, mh, v) do
      {:ok, ExSecp256k1.PublicKey.encode(pk, :uncompressed)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc false
  @spec fetch_token_balance(String.t(), integer(), String.t(), integer()) :: {:ok, integer()} | {:error, String.t()}
  def fetch_token_balance(_wallet, _chain_id, _contract, _decimals) do
    {:error, "Token balance fetching not yet implemented - requires RPC connection"}
  end

  @doc false
  @spec audit_log(String.t() | nil, String.t(), map()) :: :ok
  def audit_log(wa, event, details) do
    %AuthAuditLog{} |> AuthAuditLog.changeset(%{wallet_address: wa, event: event, details: details}) |> Repo.insert()
    :ok
  rescue; _ -> :ok
  end

  defp maybe_filter_expired(q) do
    now = DateTime.utc_now()
    from r in q, where: is_nil(r.expires_at) or r.expires_at > ^now
  end
end
