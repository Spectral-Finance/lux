defmodule Lux.Integrations.Twitter do
  @moduledoc """
  Common settings, OAuth 2.0 authentication helpers, and URL parameter interpolation
  for Twitter API v2 integration.
  """

  @doc """
  Common request settings for Twitter API v2 calls.
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
  Common headers for Twitter API v2 calls.
  """
  def headers, do: [{"Content-Type", "application/json"}]

  @doc """
  Common auth settings for Twitter API v2 calls.
  """
  def auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_auth_header/1
    }
  end

  @doc """
  Resolves the Twitter OAuth 2.0 Bearer token from application config or environment.
  """
  @spec resolve_bearer_token() :: String.t()
  def resolve_bearer_token do
    api_keys = Application.get_env(:lux, :api_keys, [])
    Keyword.get(api_keys, :twitter_bearer_token) ||
      Keyword.get(api_keys, :twitter) ||
      System.get_env("TWITTER_BEARER_TOKEN") ||
      ""
  end

  @doc """
  Adds OAuth 2.0 Bearer authorization header and interpolates path parameters on a Lux.Lens struct.
  """
  @spec add_auth_header(Lux.Lens.t()) :: Lux.Lens.t()
  def add_auth_header(%Lux.Lens{} = lens) do
    token = resolve_bearer_token()
    interpolated_url = interpolate_url(lens.url, lens.params)

    %{
      lens
      | url: interpolated_url,
        headers: lens.headers ++ [{"Authorization", "Bearer #{token}"}]
    }
  end

  @spec add_auth_header(Plug.Conn.t()) :: Plug.Conn.t()
  def add_auth_header(%Plug.Conn{} = conn) do
    token = resolve_bearer_token()
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
  end

  defp interpolate_url(url, params) when is_binary(url) and is_map(params) do
    Enum.reduce(params, url, fn {key, value}, acc ->
      placeholder = ":#{key}"

      if is_binary(value) or is_integer(value) do
        String.replace(acc, placeholder, to_string(value))
      else
        acc
      end
    end)
  end

  defp interpolate_url(url, _params), do: url
end
