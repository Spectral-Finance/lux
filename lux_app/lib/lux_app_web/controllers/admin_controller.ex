defmodule LuxAppWeb.AdminController do
  use LuxAppWeb, :controller

  def index(conn, _params) do
    conn
    |> put_status(:ok)
    |> json(%{status: "ok", message: "Welcome Admin"})
  end
end
