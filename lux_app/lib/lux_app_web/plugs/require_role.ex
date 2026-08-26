defmodule LuxAppWeb.Plugs.RequireRole do
  import Plug.Conn
  import Phoenix.Controller

  def init(roles) when is_list(roles), do: roles
  def init(role), do: [role]

  def call(conn, roles) do
    user_role = get_session(conn, :role)

    if user_role in roles do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Insufficient permissions"})
      |> halt()
    end
  end
end
