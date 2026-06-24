defmodule LuxAppWeb.Web3AuthController do
  @moduledoc """
  Controller for Web3 authentication endpoints.

  Provides RESTful endpoints for the EIP-4361 sign-in flow,
  session management, and permission checking.
  """

  use LuxAppWeb, :controller
  alias LuxApp.Contexts.Web3Auth
  alias LuxApp.Repo

  @doc """
  Issues a new sign-in challenge.
  """
  def create_challenge(conn, params) do
    wallet = Map.get(params, "wallet_address", "")
    domain = Map.get(params, "domain", "lux.spectral.finance")
    chain_id = Map.get(params, "chain_id", "1") |> String.to_integer()
    statement = Map.get(params, "statement")

    opts = [
      domain: domain,
      chain_id: chain_id,
      statement: statement
    ]

    case Web3Auth.issue_challenge(wallet, opts) do
      {:ok, session} ->
        message = Web3Auth.format_siwe_message(session)

        conn
        |> put_status(:created)
        |> json(%{
          session_id: session.id,
          message: message,
          expires_at: Web3Auth.format_datetime(session.expires_at)
        })

      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Could not issue challenge", details: format_errors(changeset)})
    end
  end

  @doc """
  Verifies a signed message and authenticates the user.
  """
  def verify_signature(conn, params) do
    session_id = Map.get(params, "session_id", "")
    signature = Map.get(params, "signature", "")

    case Web3Auth.verify_signature(session_id, signature,
           ip_address: conn.remote_ip |> Tuple.to_list() |> Enum.join("."),
           user_agent: get_req_header(conn, "user-agent") |> List.first()
         ) do
      {:ok, session} ->
        conn
        |> put_status(:ok)
        |> json(%{
          authenticated: true,
          wallet_address: session.wallet_address,
          roles: session.roles,
          permissions: session.permissions,
          session_id: session.id,
          expires_at: Web3Auth.format_datetime(session.expires_at)
        })

      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{authenticated: false, error: reason})
    end
  end

  @doc """
  Gets session details by ID.
  """
  def get_session(conn, %{"id" => session_id}) do
    case Repo.get(LuxApp.Schemas.Web3AuthSession, session_id) do
      %LuxApp.Schemas.Web3AuthSession{} = session ->
        json(conn, %{
          session_id: session.id,
          wallet_address: session.wallet_address,
          chain_id: session.chain_id,
          domain: session.domain,
          issued_at: Web3Auth.format_datetime(session.issued_at),
          expires_at: Web3Auth.format_datetime(session.expires_at),
          revoked_at: if(session.revoked_at, do: Web3Auth.format_datetime(session.revoked_at)),
          roles: session.roles,
          permissions: session.permissions,
          valid: Web3Auth.valid_session?(session)
        })

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Session not found"})
    end
  end

  @doc """
  Revokes a session.
  """
  def revoke_session(conn, %{"id" => session_id}) do
    case Web3Auth.revoke_session(session_id) do
      {:ok, session} ->
        json(conn, %{
          revoked: true,
          session_id: session.id,
          revoked_at: Web3Auth.format_datetime(session.revoked_at)
        })

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Session not found"})

      {:error, :already_revoked} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Session already revoked"})

      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Could not revoke session", details: format_errors(changeset)})
    end
  end

  @doc """
  Revokes all sessions for the authenticated wallet.
  """
  def revoke_all_sessions(conn, _params) do
    wallet = conn.assigns[:wallet_address]

    unless wallet do
      conn
      |> put_status(401)
      |> json(%{error: "Authentication required"})
    else
      query =
        from s in LuxApp.Schemas.Web3AuthSession,
          where: s.wallet_address == ^wallet and is_nil(s.revoked_at),
          update: [set: [revoked_at: ^DateTime.utc_now()]]

      {count, _} = Repo.update_all(query, [])

      Web3Auth.audit_log(wallet, "all_sessions_revoked_self", %{count: count})

      json(conn, %{
        revoked: true,
        count: count
      })
    end
  end

  @doc """
  Checks permissions for the authenticated wallet.
  """
  def check_permissions(conn, params) do
    wallet = conn.assigns[:wallet_address]

    unless wallet do
      conn
      |> put_status(401)
      |> json(%{error: "Authentication required"})
    else
      resource = Map.get(params, "resource")
      action = Map.get(params, "action")

      result =
        cond do
          resource and action ->
            Web3Auth.has_permission?(wallet, resource, action)

          true ->
            roles = Web3Auth.resolve_roles(wallet)
            permissions = Web3Auth.resolve_permissions(roles)
            %{roles: roles, permissions: permissions}
        end

      json(conn, result)
    end
  end

  @doc """
  Lists roles for the authenticated wallet.
  """
  def list_roles(conn, _params) do
    wallet = conn.assigns[:wallet_address]

    unless wallet do
      conn
      |> put_status(401)
      |> json(%{error: "Authentication required"})
    else
      roles = Web3Auth.list_roles(wallet)

      json(conn, %{
        wallet_address: wallet,
        roles: Enum.map(roles, fn r -> %{role: r.role, expires_at: r.expires_at} end)
      })
    end
  end

  @doc """
  Lists audit logs (requires authentication).
  """
  def list_audit_logs(conn, params) do
    wallet = conn.assigns[:wallet_address]

    unless wallet do
      conn
      |> put_status(401)
      |> json(%{error: "Authentication required"})
    else
      case Web3Auth.list_audit_logs(params) do
        {:ok, logs} ->
          json(conn, %{logs: logs})

        {:error, reason} ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: reason})
      end
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _meta} -> msg end)
  end
end
