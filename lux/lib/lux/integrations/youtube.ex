defmodule Lux.Integrations.YouTube do
  @moduledoc """
  Common settings and functions for YouTube Data API v3 integration.
  """

  @doc """
  Common request settings for YouTube API calls.
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
  Common headers for YouTube API calls.
  """
  def headers, do: [{"Content-Type", "application/json"}]

  @doc """
  Common auth settings for YouTube API calls.
  """
  def auth, do: %{
    type: :custom,
    auth_function: &__MODULE__.add_auth_header/1
  }

  @doc """
  Adds YouTube API key authorization as a query parameter for Lens-based calls.
  """
  @spec add_auth_header(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth_header(%Lux.Lens{} = lens) do
    api_key = Lux.Config.youtube_api_key()
    separator = if String.contains?(lens.url, "?"), do: "&", else: "?"
    %{lens | url: lens.url <> separator <> "key=#{api_key}"}
  end

  @spec add_auth_header(Plug.Conn.t()) :: Plug.Conn.t()
  def add_auth_header(%Plug.Conn{} = conn) do
    api_key = Lux.Config.youtube_api_key()
    query = if conn.query_string == "", do: "key=#{api_key}", else: conn.query_string <> "&key=#{api_key}"
    %{conn | query_string: query}
  end
end
