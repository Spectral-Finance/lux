defmodule LuxAppWeb.Plugs.RequireAuth do
  @moduledoc """
  Plug requiring active Web3 authentication and session TTL validation.
  Supports optional role and permission checks.
  """
  import Plug.Conn
  import Phoenix.Controller
  alias LuxAppWeb.Auth.{SessionManager, Permissions}

  def init(opts), do: opts

  def call(conn, opts) do
    required_role = Keyword.get(opts, :role)
    required_permission = Keyword.get(opts, :permission)

    case SessionManager.validate_session(conn) do
      {:ok, valid_conn} ->
        role = get_session(valid_conn, :role) || "user"
        
        cond do
          required_role && role != to_string(required_role) ->
            valid_conn
            |> put_status(:forbidden)
            |> json(%{error: "Forbidden: Insufficient role"})
            |> halt()

          required_permission && not Permissions.has_permission?(role, required_permission) ->
            valid_conn
            |> put_status(:forbidden)
            |> json(%{error: "Forbidden: Insufficient permissions"})
            |> halt()

          true ->
            valid_conn
        end

      {:error, :session_expired, expired_conn} ->
        expired_conn
        |> put_status(:unauthorized)
        |> json(%{error: "Session expired. Please sign in again."})
        |> halt()

      {:error, _, unauth_conn} ->
        unauth_conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
        |> halt()
    end
  end
end
