defmodule LuxAppWeb.Plugs.Web3AuthPlug do
  @moduledoc """
  Plug for enforcing Web3 authentication on API routes.
  """
  alias LuxApp.Contexts.Web3Auth

  @spec init(opts :: keyword()) :: keyword()
  def init(opts \ []), do: opts

  @spec call(conn :: Plug.Conn.t(), opts :: keyword()) :: Plug.Conn.t()
  def call(conn, _opts \ []) do
    wallet_address =
      conn
      |> Plug.Conn.get_req_header("x-web3-address")
      |> case do
        [address] -> address
        [] -> nil
      end

    case wallet_address do
      nil ->
        conn
        |> Plug.Conn.put_status(401)
        |> Plug.Conn.put_resp_header("www-authenticate", "Web3")
        |> Plug.Conn.render(LuxAppWeb.ErrorJSON, "401.json", %{
          message: "Authentication required. Provide X-Web3-Address header."
        })
        |> Plug.Conn.halt()

      address ->
        conn
        |> Plug.Conn.assign(:wallet_address, Web3Auth.normalize_address(address))
        |> Plug.Conn.assign(:web3_authenticated, true)
    end
  end

  @spec require_role(conn :: Plug.Conn.t(), opts :: keyword()) :: Plug.Conn.t()
  def require_role(conn, opts) do
    unless conn.assigns[:web3_authenticated] do
      return_unauthorized(conn)
    else
      required_role = Keyword.fetch!(opts, :role)
      if Web3Auth.has_role?(conn.assigns.wallet_address, required_role) do
        conn |> Plug.Conn.assign(:required_role, required_role)
      else
        conn
        |> Plug.Conn.put_status(403)
        |> Plug.Conn.render(LuxAppWeb.ErrorJSON, "403.json", %{message: "Requires role: #{required_role}"})
        |> Plug.Conn.halt()
      end
    end
  end

  @spec require_permission(conn :: Plug.Conn.t(), opts :: keyword()) :: Plug.Conn.t()
  def require_permission(conn, opts) do
    unless conn.assigns[:web3_authenticated] do
      return_unauthorized(conn)
    else
      resource = Keyword.fetch!(opts, :resource)
      action = Keyword.fetch!(opts, :action)
      if Web3Auth.has_permission?(conn.assigns.wallet_address, resource, action) do
        conn |> Plug.Conn.assign(:required_resource, resource) |> Plug.Conn.assign(:required_action, action)
      else
        conn
        |> Plug.Conn.put_status(403)
        |> Plug.Conn.render(LuxAppWeb.ErrorJSON, "403.json", %{message: "Permission denied: #{resource}:#{action}"})
        |> Plug.Conn.halt()
      end
    end
  end

  @spec optional_auth(conn :: Plug.Conn.t(), opts :: keyword()) :: Plug.Conn.t()
  def optional_auth(conn, _opts \ []) do
    wallet_address =
      conn
      |> Plug.Conn.get_req_header("x-web3-address")
      |> case do
        [address] -> Web3Auth.normalize_address(address)
        [] -> nil
      end
    conn
    |> Plug.Conn.assign(:wallet_address, wallet_address)
    |> Plug.Conn.assign(:web3_authenticated, !!wallet_address)
  end

  defp return_unauthorized(conn) do
    conn
    |> Plug.Conn.put_status(401)
    |> Plug.Conn.put_resp_header("www-authenticate", "Web3")
    |> Plug.Conn.render(LuxAppWeb.ErrorJSON, "401.json", %{message: "Authentication required"})
    |> Plug.Conn.halt()
  end
end
