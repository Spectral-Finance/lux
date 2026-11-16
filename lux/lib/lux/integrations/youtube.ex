defmodule Lux.Integrations.YouTube do
  @moduledoc """
  Common settings, authentication helpers, and API key / OAuth 2.0 Bearer resolution
  for YouTube Data API v3 and YouTube Analytics integration.
  """

  @doc """
  Common headers for YouTube Data API v3 calls.
  """
  def headers, do: [{"Content-Type", "application/json"}]

  @doc """
  Common auth settings for YouTube Data API v3 calls.
  """
  def auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_auth/1
    }
  end

  @doc """
  Resolves the YouTube Data API v3 key from application config or environment.
  """
  @spec resolve_api_key() :: String.t()
  def resolve_api_key do
    api_keys = Application.get_env(:lux, :api_keys, [])

    Keyword.get(api_keys, :youtube_api_key) ||
      Keyword.get(api_keys, :youtube) ||
      System.get_env("YOUTUBE_API_KEY") ||
      ""
  end

  @doc """
  Attaches the YouTube API key query parameter or Bearer header to a Lux.Lens struct.
  """
  @spec add_auth(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth(%Lux.Lens{} = lens) do
    api_key = resolve_api_key()

    updated_params =
      if api_key != "" and not Map.has_key?(lens.params, :key) and not Map.has_key?(lens.params, "key") do
        Map.put(lens.params, "key", api_key)
      else
        lens.params
      end

    %{lens | params: updated_params}
  end

  @spec add_auth(Plug.Conn.t()) :: Plug.Conn.t()
  def add_auth(%Plug.Conn{} = conn) do
    api_key = resolve_api_key()
    Plug.Conn.put_req_header(conn, "x-goog-api-key", api_key)
  end
end
