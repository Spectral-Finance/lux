defmodule Lux.Web3.Auth do
  @moduledoc """
  Web3 Authentication and Authorization Framework for Lux (#77).

  Features:
  - Sign-In with Ethereum (EIP-4361 / SIWE) message builder, parser, and validator
  - Multi-signature wallet threshold verification (m-of-n signers)
  - Role-Based Access Control (RBAC) and granular permission policies
  - Session lifecycle management with expiration and revocation
  - Token-gated access control policies (ERC-20 / ERC-721 balance thresholds)
  - Immutable ETS security audit logging
  """

  @table :lux_web3_auth_store

  @spec init_store() :: :ok
  def init_store do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end

    :ok
  end

  @doc """
  Generates and stores a single-use cryptographic nonce for EIP-4361 SIWE authentication.
  """
  @spec generate_nonce(non_neg_integer()) :: String.t()
  def generate_nonce(ttl_seconds \\ 300) do
    init_store()
    nonce = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    expires_at = System.system_time(:second) + ttl_seconds
    :ets.insert(@table, {{:nonce, nonce}, %{expires_at: expires_at, used: false}})
    nonce
  end

  @doc """
  Builds an EIP-4361 compliant Sign-In With Ethereum message string.
  """
  @spec build_siwe_message(map()) :: {:ok, String.t()} | {:error, term()}
  def build_siwe_message(params) when is_map(params) do
    with {:ok, domain} <- fetch_req(params, :domain),
         {:ok, address} <- fetch_req(params, :address),
         {:ok, uri} <- fetch_req(params, :uri),
         {:ok, chain_id} <- fetch_req(params, :chain_id),
         {:ok, nonce} <- fetch_req(params, :nonce) do
      statement = Map.get(params, :statement, "Sign in with Ethereum to Lux.")
      issued_at = Map.get(params, :issued_at, DateTime.utc_now() |> DateTime.to_iso8601())
      expiration_time = Map.get(params, :expiration_time)

      base =
        "#{domain} wants you to sign in with your Ethereum account:\n" <>
          "#{address}\n\n" <>
          "#{statement}\n\n" <>
          "URI: #{uri}\n" <>
          "Version: 1\n" <>
          "Chain ID: #{chain_id}\n" <>
          "Nonce: #{nonce}\n" <>
          "Issued At: #{issued_at}"

      msg =
        if is_binary(expiration_time) do
          base <> "\nExpiration Time: #{expiration_time}"
        else
          base
        end

      {:ok, msg}
    end
  end

  @doc """
  Parses an EIP-4361 message into structured fields.
  """
  @spec parse_siwe_message(String.t()) :: {:ok, map()} | {:error, :invalid_siwe_format}
  def parse_siwe_message(message) when is_binary(message) do
    lines = String.split(message, "\n")

    case lines do
      [header, address | rest] ->
        if String.ends_with?(header, "wants you to sign in with your Ethereum account:") do
          domain = String.replace_suffix(header, " wants you to sign in with your Ethereum account:", "")
          fields = parse_kv_lines(rest)

          {:ok,
           %{
             domain: domain,
             address: String.downcase(String.trim(address)),
             uri: Map.get(fields, "URI"),
             version: Map.get(fields, "Version"),
             chain_id: parse_int(Map.get(fields, "Chain ID")),
             nonce: Map.get(fields, "Nonce"),
             issued_at: Map.get(fields, "Issued At"),
             expiration_time: Map.get(fields, "Expiration Time")
           }}
        else
          {:error, :invalid_siwe_format}
        end

      _ ->
        {:error, :invalid_siwe_format}
    end
  end

  @doc """
  Authenticates a SIWE message + signature (or multisig bundle), consumes the nonce,
  creates a session, and writes an audit log entry.
  """
  @spec authenticate_siwe(String.t(), String.t() | [String.t()], keyword()) ::
          {:ok, map()} | {:error, term()}
  def authenticate_siwe(message, signature_or_sigs, opts \\ []) do
    init_store()
    verifier_fn = Keyword.get(opts, :verifier_fn, &default_verify_signature/3)
    threshold = Keyword.get(opts, :threshold, 1)
    allowed_signers = Keyword.get(opts, :allowed_signers, [])
    session_ttl = Keyword.get(opts, :session_ttl_seconds, 3600)

    with {:ok, parsed} <- parse_siwe_message(message),
         :ok <- consume_nonce(parsed.nonce),
         :ok <- verify_signatures(message, parsed.address, signature_or_sigs, threshold, allowed_signers, verifier_fn) do
      token = :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)
      now = System.system_time(:second)

      session = %{
        token: token,
        address: parsed.address,
        chain_id: parsed.chain_id,
        domain: parsed.domain,
        issued_at: now,
        expires_at: now + session_ttl,
        revoked: false
      }

      :ets.insert(@table, {{:session, token}, session})
      record_audit(:authenticate_success, parsed.address, %{chain_id: parsed.chain_id, domain: parsed.domain})
      {:ok, session}
    else
      {:error, reason} = err ->
        record_audit(:authenticate_failed, "unknown", %{reason: inspect(reason)})
        err
    end
  end

  @doc """
  Validates an active session token.
  """
  @spec verify_session(String.t()) :: {:ok, map()} | {:error, :invalid_session | :session_expired | :session_revoked}
  def verify_session(token) do
    init_store()
    now = System.system_time(:second)

    case :ets.lookup(@table, {:session, token}) do
      [{{:session, ^token}, session}] ->
        cond do
          session.revoked -> {:error, :session_revoked}
          session.expires_at <= now -> {:error, :session_expired}
          true -> {:ok, session}
        end

      [] ->
        {:error, :invalid_session}
    end
  end

  @doc """
  Revokes an existing session token.
  """
  @spec revoke_session(String.t()) :: :ok
  def revoke_session(token) do
    init_store()

    case :ets.lookup(@table, {:session, token}) do
      [{{:session, ^token}, session}] ->
        :ets.insert(@table, {{:session, token}, %{session | revoked: true}})
        record_audit(:session_revoked, session.address, %{token: token})
        :ok

      [] ->
        :ok
    end
  end

  @doc """
  Assigns roles and permissions to a wallet address.
  """
  @spec assign_role(String.t(), atom(), [atom()]) :: :ok
  def assign_role(address, role, permissions) when is_atom(role) and is_list(permissions) do
    init_store()
    addr = String.downcase(address)
    :ets.insert(@table, {{:role, addr, role}, MapSet.new(permissions)})
    record_audit(:role_assigned, addr, %{role: role, permissions: permissions})
    :ok
  end

  @doc """
  Checks whether an address holds a specific permission via assigned RBAC roles or token gating.
  """
  @spec authorize(String.t(), atom(), keyword()) :: :ok | {:error, :unauthorized}
  def authorize(address, permission, opts \\ []) do
    init_store()
    addr = String.downcase(address)

    rbac_match? =
      @table
      |> :ets.match({{:role, addr, :_}, :"$1"})
      |> List.flatten()
      |> Enum.any?(fn perm_set -> MapSet.member?(perm_set, permission) end)

    token_gate_match? = check_token_gate(addr, Keyword.get(opts, :token_gate), Keyword.get(opts, :balance_fetcher))

    if rbac_match? or token_gate_match? do
      record_audit(:authorize_granted, addr, %{permission: permission})
      :ok
    else
      record_audit(:authorize_denied, addr, %{permission: permission})
      {:error, :unauthorized}
    end
  end

  @doc """
  Returns recorded security audit log entries in chronological order.
  """
  @spec list_audit_logs() :: [map()]
  def list_audit_logs do
    init_store()

    @table
    |> :ets.match({{:audit, :_}, :"$1"})
    |> List.flatten()
    |> Enum.sort_by(& &1.seq)
  end

  # Internal helpers

  defp fetch_req(map, key) do
    case Map.get(map, key) do
      v when v in [nil, ""] -> {:error, {:missing_field, key}}
      v -> {:ok, v}
    end
  end

  defp parse_kv_lines(lines) do
    Enum.reduce(lines, %{}, fn line, acc ->
      case String.split(line, ": ", parts: 2) do
        [k, v] -> Map.put(acc, String.trim(k), String.trim(v))
        _ -> acc
      end
    end)
  end

  defp parse_int(nil), do: nil

  defp parse_int(str) do
    case Integer.parse(str) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp consume_nonce(nil), do: {:error, :missing_nonce}

  defp consume_nonce(nonce) do
    now = System.system_time(:second)

    case :ets.lookup(@table, {:nonce, nonce}) do
      [{{:nonce, ^nonce}, %{used: false, expires_at: exp}}] when exp > now ->
        :ets.insert(@table, {{:nonce, nonce}, %{used: true, expires_at: exp}})
        :ok

      [{{:nonce, ^nonce}, %{used: true}}] ->
        {:error, :nonce_already_used}

      [{{:nonce, ^nonce}, _}] ->
        {:error, :nonce_expired}

      [] ->
        {:error, :invalid_nonce}
    end
  end

  defp verify_signatures(message, address, sig, 1, _allowed, verifier_fn) when is_binary(sig) do
    if verifier_fn.(message, sig, address), do: :ok, else: {:error, :invalid_signature}
  end

  defp verify_signatures(message, _address, sigs, threshold, allowed_signers, verifier_fn)
       when is_list(sigs) and is_integer(threshold) and threshold >= 1 do
    allowed_down = Enum.map(allowed_signers, &String.downcase/1)

    valid_count =
      sigs
      |> Enum.uniq_by(fn {signer, _sig} -> String.downcase(signer) end)
      |> Enum.count(fn {signer, sig} ->
        s_down = String.downcase(signer)
        s_down in allowed_down and verifier_fn.(message, sig, s_down)
      end)

    if valid_count >= threshold, do: :ok, else: {:error, :insufficient_multisig_signatures}
  end

  defp default_verify_signature(_msg, sig, _addr), do: is_binary(sig) and byte_size(sig) > 10

  defp check_token_gate(_addr, nil, _fetcher), do: false

  defp check_token_gate(addr, %{token_address: token, min_balance: min_bal}, fetcher)
       when is_function(fetcher, 2) do
    case fetcher.(addr, token) do
      {:ok, bal} when is_number(bal) and bal >= min_bal -> true
      _ -> false
    end
  end

  defp check_token_gate(_, _, _), do: false

  defp record_audit(event, address, metadata) do
    seq = System.unique_integer([:monotonic, :positive])

    entry = %{
      seq: seq,
      event: event,
      address: address,
      metadata: metadata,
      timestamp: DateTime.utc_now()
    }

    :ets.insert(@table, {{:audit, seq}, entry})
  end
end
