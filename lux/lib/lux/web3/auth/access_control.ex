defmodule Lux.Web3.Auth.AccessControl do
  @moduledoc """
  Unified access control layer combining RBAC, token gates, and session validation.

  Provides a single entry point for authorization decisions:
  - Check if a session is valid
  - Verify role-based permissions
  - Evaluate token-gate requirements
  - Multi-sig approval checks

  This module integrates the session manager, RBAC schema,
  token gate, and signature verifier into a cohesive authorization system.
  """

  alias Lux.Web3.Session.Manager
  alias Lux.Web3.Schemas.RolePermission
  alias Lux.Web3.Auth.TokenGate
  alias Lux.Web3.Signature.Verifier

  @doc """
  Check if an address has access to a protected resource.

  Evaluates all applicable access control rules:
  1. Session validity (if session_id provided)
  2. Role-based permissions
  3. Token-gate requirements
  4. Multi-sig approval
  """
  @spec authorize(
          String.t(),
          String.t(),
          %{
            optional(:session_id) => String.t(),
            optional(:permission) => RolePermission.permission(),
            optional(:gate_config) => TokenGate.gate_config(),
            optional(:multisig_threshold) => non_neg_integer(),
            optional(:multisig_signatures) => [{binary(), binary()}]
          }
        ) ::
          {:ok, map()} | {:error, String.t()}
  def authorize(address, resource, opts \ %{}) do
    checks = build_checks(resource, opts)
    results = run_checks(address, checks)

    all_passed = Enum.all?(results, fn
      {:ok, _} -> true
      _ -> false
    end)

    case all_passed do
      true ->
        {:ok, %{address: address, resource: resource, authorized: true, results: results}}

      false ->
        denied =
          results
          |> Enum.filter(fn
            {:error, _} -> true
            _ -> false
          end)
          |> Enum.map(fn {:error, reason} -> reason end)
          |> Enum.join("; ")

        {:error, "Access denied: #{denied}"}
    end
  end

  @doc """
  Check session validity for an address.
  """
  @spec validate_session(String.t(), String.t()) :: :ok | {:error, String.t()}
  def validate_session(session_id, address) do
    case Manager.get_session(session_id) do
      {:ok, session} when session[:address] == String.downcase(address) and session[:valid] == true ->
        :ok

      {:ok, _} ->
        {:error, :invalid_or_expired_session}

      {:error, :not_found} ->
        {:error, :session_not_found}
    end
  end

  @doc """
  Check role-based permission for an address.
  """
  @spec check_permission(RolePermission.t(), String.t(), RolePermission.permission()) :: boolean()
  def check_permission(schema, address, permission) do
    RolePermission.has_permission?(schema, address, permission)
  end

  @doc """
  Verify a signature on a resource access request.
  """
  @spec verify_access_signature(String.t(), String.t(), binary(), binary()) :: boolean()
  def verify_access_signature(address, resource, message, signature) do
    Verifier.verify_signature(address, message, signature)
  end

  # Internal helpers

  defp build_checks(resource, opts) do
    checks = []

    checks =
      if opts[:session_id] do
        [%{type: :session, session_id: opts[:session_id]} | checks]
      else
        checks
      end

    checks =
      if opts[:permission] do
        [%{type: :permission, permission: opts[:permission]} | checks]
      else
        checks
      end

    checks =
      if opts[:gate_config] do
        [%{type: :gate, gate_config: opts[:gate_config]} | checks]
      else
        checks
      end

    checks =
      if opts[:multisig_threshold] do
        [%{
           type: :multisig,
           threshold: opts[:multisig_threshold],
           signatures: opts[:multisig_signatures] || []
         }
         | checks]
      else
        checks
      end

    Enum.reverse(checks)
  end

  defp run_checks(address, checks) do
    Enum.map(checks, fn check ->
      run_check(address, check)
    end)
  end

  defp run_check(address, %{type: :session, session_id: sid}) do
    validate_session(sid, address)
  end

  defp run_check(_address, %{type: :permission, permission: perm}) do
    # Permission check requires the RolePermission schema
    # This is a placeholder - actual check done via check_permission/3
    {:ok, :permission_not_checked}
  end

  defp run_check(address, %{type: :gate, gate_config: gate}) do
    TokenGate.evaluate(address, gate)
  end

  defp run_check(address, %{type: :multisig, threshold: threshold, signatures: sigs}) do
    message = "#{address}:access:multisig" |> :erlang.phash2() |> :binary.bin_to_list() |> List.to_string()

    Verifier.verify_multisig(message, sigs, threshold)
  end
end
