defmodule Lux.Integrations.YouTube do
  @moduledoc """
  Common settings and functions for YouTube Data API v3 integration.

  Authentication uses API key for public data access.

  ## Configuration

  Configure in your application config:

      config :lux, :api_keys,
        youtube: "your_youtube_api_key"

  ## Rate Limits

  YouTube Data API v3 uses a quota system:
  - Default quota: 10,000 units per day
  - Search: 100 units per request
  - Videos/channels: 1 unit per request
  """

  @doc """
  Common JSON content-type header for YouTube API calls.
  """
  def headers, do: [{"Content-Type", "application/json"}]

  @doc """
  API key auth settings for YouTube Data API.
  """
  def api_key_auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_api_key/1
    }
  end

  @doc """
  Adds the YouTube API key as a query parameter.
  """
  @spec add_api_key(Lux.Lens.t()) :: Lux.Lens.t()
  def add_api_key(%Lux.Lens{} = lens) do
    key = get_api_key()
    params = Map.put(lens.params || %{}, "key", key)
    %{lens | params: params}
  end

  @spec add_api_key(Plug.Conn.t()) :: Plug.Conn.t()
  def add_api_key(%Plug.Conn{} = conn) do
    key = get_api_key()
    query = conn.query_string
    new_query = if query == "", do: "key=#{key}", else: "#{query}&key=#{key}"
    %{conn | query_string: new_query}
  end

  defp get_api_key do
    Application.get_env(:lux, :api_keys, [])[:youtube] ||
      System.get_env("YOUTUBE_API_KEY") ||
      "test_api_key"
  end
end
