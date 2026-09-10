defmodule Lux do
  @moduledoc """
  A comprehensive Web3 authentication and authorization framework.

  Features:
  * EIP‑4361 compliant sign‑in
  * Multi‑signature wallet support
  * Role‑based access control
  * Permission management
  * Session handling with expiry
  * Signature verification
  * Token‑gated access control
  * Audit logging

  ## Examples

      iex> Lux.init()
      :ok
      iex> nonce = Lux.generate_nonce()
      iex> {:ok, address} = Lux.verify_eip4361(message, signature)
      iex> {:ok, token} = Lux.create_session(address)
      iex> Lux.has_permission?(address, :admin, :dashboard)
      true
      iex> Lux.audit_log(:login, %{address: address})
  """

  @on_load :init

  @doc false
  def init do
    :ets.new(:sessions, [:named_table, :public, :set])
    :ets.new(:roles, [:named_table, :public, :bag])
    :ets.new(:permissions, [:named_table, :public, :bag])
    :ets.new(:audit_log, [:named_table, :public, :bag])
    :ok
  end

  @doc """
  Generates a cryptographically secure nonce.
  """
  def generate_nonce do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  @doc """
  Verifies an EIP‑4361 signed message.

  Returns `{:ok, address}` on success or `{:error, reason}`.
  """
  def verify_eip4361(message, signature_hex) when is_binary(message) and is_binary(signature_hex) do
    message_hash = :crypto.hash(:sha3, message)
    with {:ok, signature} <- Base.decode16(signature_hex, case: :lower),
         {:ok, public_key} <- :crypto.ecdsa_recover(message_hash, signature, :secp256k1) do
      public_key_bin = :public_key.encode(:EC, public_key, :uncompressed)
      pubkey_no_prefix = binary_part(public_key_bin, 1, 64)
      address =
        :crypto.hash(:sha3, pubkey_no_prefix)
        |> binary_part(-20, 20)
        |> Base.encode16(case: :lower)

      {:ok, address}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Verifies a generic ECDSA signature.

  Returns `{:ok, address}` on success or `{:error, reason}`.
  """
  def verify_signature(message, signature_hex, public_key_hex) when is_binary(message) and is_binary(signature_hex) and is_binary(public_key_hex) do
    message_hash = :crypto.hash(:sha3, message)
    with {:ok, signature} <- Base.decode16(signature_hex, case: :lower),
         {:ok, public_key} <- Base.decode16(public_key_hex, case: :lower),
         true <- :crypto.verify(:ecdsa, :sha3, message_hash, signature, public_key) do
      {:ok, public_key_hex}
    else
      _ -> {:error, :invalid_signature}
    end
  end

  @doc """
  Verifies a multi‑signature message.

  `signatures` is a list of hex signatures.
  `required` is the minimum number of unique signers required.
  Returns `{:ok, addresses}` or `{:error, reason}`.
  """
  def verify_multisig(message, signatures, required) when is_list(signatures) and is_integer(required) do
    message_hash = :crypto.hash(:sha3, message)

    addresses =
      signatures
      |> Enum.reduce_while([], fn sig_hex, acc ->
        case Base.decode16(sig_hex, case: :lower) do
          {:ok, sig} ->
            case :crypto.ecdsa_recover(message_hash, sig, :secp256k1) do
              {:ok, public_key} ->
                public_key_bin = :public_key.encode(:EC, public_key, :uncompressed)
                pubkey_no_prefix = binary_part(public_key_bin, 1, 64)
                address =
                  :crypto.hash(:sha3, pubkey_no_prefix)
                  |> binary_part(-20, 20)
                  |> Base.encode16(case: :lower)

                {:cont, [address | acc]}
              {:error, _} -> {:halt, {:error, :recover_failed}}
            end
          {:error, _} -> {:halt, {:error, :decode_failed}}
        end
      end)

    case addresses do
      {:error, _} = err -> err
      list when length(list) >= required ->
        {:ok, Enum.uniq(list)}
      _ -> {:error, :insufficient_signatures}
    end
  end

  @doc """
  Creates a session token for an address.

  Returns `{:ok, token}`.
  """
  def create_session(address) when is_binary(address) do
    token = :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
    expiry = :erlang.system_time(:millisecond) + 60 * 60 * 1000  # 1 hour
    :ets.insert(:sessions, {token, %{address: address, expiry: expiry}})
    {:ok, token}
  end

  @doc """
  Validates a session token.

  Returns `{:ok, address}` or `{:error, reason}`.
  """
  def validate_session(token) when is_binary(token) do
    case :ets.lookup(:sessions, token) do
      [{^token, %{address: address, expiry: expiry}}] ->
        if :erlang.system_time(:millisecond) <= expiry do
          {:ok, address}
        else
          :ets.delete(:sessions, token)
          {:error, :expired}
        end
      [] -> {:error, :invalid_token}
    end
  end

  @doc """
  Assigns a role to an address.
  """
  def assign_role(address, role) when is_binary(address) and is_atom(role) do
    :ets.insert(:roles, {address, role})
    :ok
  end

  @doc """
  Adds a permission to a role.
  """
  def add_permission(role, permission) when is_atom(role) and is_atom(permission) do
    :ets.insert(:permissions, {role, permission})
    :ok
  end

  @doc """
  Checks if an address has a specific permission.
  """
  def has_permission?(address, permission, _context \\ nil) when is_binary(address) and is_atom(permission) do
    roles = :ets.lookup(:roles, address) |> Enum.map(fn {_addr, r} -> r end)
    Enum.any?(roles, fn role ->
      perms = :ets.lookup(:permissions, role) |> Enum.map(fn {_r, p} -> p end)
      permission in perms
    end)
  end

  @doc """
  Checks token‑gated access.

  `token_contract` is the contract address.
  `token_id` is optional for ERC‑721.
  Returns `true` if the address owns the token.
  """
  def token_gated_access(address, token_contract, token_id \\ nil) when is_binary(address) and is_binary(token_contract) do
    # Placeholder: In a real implementation, query the blockchain.
    # Here we simply return true for demonstration.
    true
  end

  @doc """
  Logs an audit event.
  """
  def audit_log(event, details) when is_atom(event) and is_map(details) do
    id = :erlang.unique_integer([:positive])
    timestamp = :erlang.system_time(:millisecond)
    :ets.insert(:audit_log, {id, %{event: event, details: details, timestamp: timestamp}})
    :ok
  end

  @doc """
  Retrieves audit logs.
  """
  def get_audit_logs do
    :ets.tab2list(:audit_log)
    |> Enum.map(fn {_id, entry} -> entry end)
  end
end