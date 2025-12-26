defmodule Lux.Integrations.Telegram do
  @moduledoc """
  Integration module for the Telegram Bot API.

  Provides necessary headers and authentication mechanisms for interacting
  with Telegram's API endpoints.
  """

  @spec headers() :: [{String.t(), String.t()}]
  def headers, do: [{"Content-Type", "application/json"}]

  @spec auth() :: %{type: :custom, auth_function: function()}
  def auth, do: %{
    type: :custom,
    auth_function: &__MODULE__.add_auth_header/1
  }

  @spec token() :: String.t()
  def token, do: Application.get_env(:lux, :api_keys)[:telegram]

  @spec add_auth_header(Lux.Lens.t() | Plug.Conn.t()) :: Lux.Lens.t() | Plug.Conn.t()
  def add_auth_header(%Lux.Lens{} = lens) do
    token = Application.get_env(:lux, :api_keys)[:telegram]
    %{lens | headers: lens.headers ++ [{"Authorization", "Bearer #{token}"}]}
  end

  def add_auth_header(%Plug.Conn{} = conn) do
    token = Application.get_env(:lux, :api_keys)[:telegram]
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
  end
end
