defmodule Lux.Integrations.Discord do
  @moduledoc """
  Common settings and functions for Discord API integration.
  """

  @doc """
  Common request settings for Discord API calls.
  """
  def request_settings do
    %{
      headers: [{"Content-Type", "application/json"}],
      auth: %{
        type: :custom,
        auth_function: &__MODULE__.add_auth_header/1
      }
    }
  end

  @doc """
  Common headers for Discord API calls.
  """
  def headers, do: [{"Content-Type", "application/json"}]

  @doc """
  Common auth settings for Discord API calls.
  """
  def auth, do: %{
    type: :custom,
    auth_function: &__MODULE__.add_auth_header/1
  }

  @doc """
  Adds Discord bot token authorization header.
  """
  @spec add_auth_header(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth_header(%Lux.Lens{} = lens) do
    token = Application.get_env(:lux, :api_keys)[:discord]
    %{lens | headers: lens.headers ++ [{"Authorization", "Bot #{token}"}]}
  end

  @spec add_auth_header(Plug.Conn.t()) :: Plug.Conn.t()
  def add_auth_header(%Plug.Conn{} = conn) do
    token = Application.get_env(:lux, :api_keys)[:discord]
    Plug.Conn.put_req_header(conn, "authorization", "Bot #{token}")
  end
end
