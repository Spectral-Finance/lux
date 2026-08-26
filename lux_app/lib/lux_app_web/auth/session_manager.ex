defmodule LuxAppWeb.Auth.SessionManager do
  @moduledoc """
  Session lifecycle management and TTL expiration enforcing for Web3 authentication.
  """

  import Plug.Conn

  @default_ttl 86_400 # 24 hours in seconds

  @doc """
  Initializes session keys including creation timestamp, expiration time, role, and chain_id.
  """
  def init_session(conn, address, role \\ "user", chain_id \\ "1", ttl \\ @default_ttl) do
    now = System.system_time(:second)
    expires_at = now + ttl

    conn
    |> put_session(:web3_address, address)
    |> put_session(:role, role)
    |> put_session(:chain_id, to_string(chain_id))
    |> put_session(:authenticated_at, now)
    |> put_session(:expires_at, expires_at)
  end

  @doc """
  Validates whether the current session is active and not expired.
  Returns `{:ok, conn}` if valid, or `{:error, reason, conn}` if expired or missing, clearing session cookies.
  """
  def validate_session(conn) do
    expires_at = get_session(conn, :expires_at)
    now = System.system_time(:second)

    cond do
      is_nil(expires_at) ->
        {:error, :unauthenticated, conn}

      now > expires_at ->
        cleaned_conn = clear_session(conn)
        {:error, :session_expired, cleaned_conn}

      true ->
        {:ok, conn}
    end
  end

  @doc """
  Renews the session TTL by resetting the expiration timestamp.
  """
  def renew_session(conn, ttl \\ @default_ttl) do
    case get_session(conn, :web3_address) do
      nil -> {:error, :unauthenticated, conn}
      address ->
        role = get_session(conn, :role) || "user"
        chain_id = get_session(conn, :chain_id) || "1"
        {:ok, init_session(conn, address, role, chain_id, ttl)}
    end
  end
end
