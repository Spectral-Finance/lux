defmodule Lux.Integrations.Twitter do
  @moduledoc """
  Integration module for the Twitter API v2.

  Provides necessary headers and authentication mechanisms for interacting
  with Twitter's API endpoints using OAuth 2.0 Bearer Token authentication.
  """

  @spec headers() :: [{String.t(), String.t()}]
  def headers, do: [{"Content-Type", "application/json"}]

  @spec auth() :: %{type: :custom, auth_function: function()}
  def auth, do: %{
    type: :custom,
    auth_function: &__MODULE__.add_auth_header/1
  }

  @spec token() :: String.t()
  def token, do: Application.get_env(:lux, :api_keys)[:twitter]

  @spec add_auth_header(Lux.Lens.t() | Plug.Conn.t()) :: Lux.Lens.t() | Plug.Conn.t()
  def add_auth_header(%Lux.Lens{} = lens) do
    token = Application.get_env(:lux, :api_keys)[:twitter]
    %{lens | headers: lens.headers ++ [{"Authorization", "Bearer #{token}"}]}
  end

  def add_auth_header(%Plug.Conn{} = conn) do
    token = Application.get_env(:lux, :api_keys)[:twitter]
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
  end
end
