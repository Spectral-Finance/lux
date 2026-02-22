defmodule Lux.Integrations.Twitter do
  @moduledoc """
  Common settings and functions for Twitter API v2 integration.

  Authentication uses OAuth 2.0 Bearer Token for read-only endpoints and
  OAuth 2.0 User Context (PKCE) or OAuth 1.0a for write endpoints.

  ## Configuration

  Configure in your application config:

      config :lux, :api_keys,
        twitter: "your_bearer_token",
        twitter_consumer_key: "your_consumer_key",
        twitter_consumer_secret: "your_consumer_secret",
        twitter_access_token: "your_access_token",
        twitter_access_token_secret: "your_access_token_secret"

  ## Rate Limits

  Twitter API v2 enforces rate limits per endpoint. The integration includes
  rate limit headers in responses. Key limits:
    - GET /tweets: 300 requests / 15 minutes (app-level)
    - POST /tweets: 100 posts / 24 hours (user-level)
  """

  @base_url "https://api.twitter.com/2"

  @doc """
  Returns the Twitter API v2 base URL.
  """
  def base_url, do: @base_url

  @doc """
  Common JSON content-type header for Twitter API calls.
  """
  def headers, do: [{"Content-Type", "application/json"}]

  @doc """
  Bearer token auth settings for read-only endpoints.
  """
  def auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_bearer_token/1
    }
  end

  @doc """
  OAuth 1.0a auth settings for write endpoints (tweets, likes, etc.).
  """
  def oauth_auth do
    %{
      type: :custom,
      auth_function: &__MODULE__.add_oauth_header/1
    }
  end

  @doc """
  Adds Bearer token Authorization header for app-only read access.
  """
  @spec add_bearer_token(Lux.Lens.t()) :: Lux.Lens.t()
  def add_bearer_token(%Lux.Lens{} = lens) do
    token = get_bearer_token()
    %{lens | headers: lens.headers ++ [{"Authorization", "Bearer #{token}"}]}
  end

  @spec add_bearer_token(Plug.Conn.t()) :: Plug.Conn.t()
  def add_bearer_token(%Plug.Conn{} = conn) do
    token = get_bearer_token()
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
  end

  @doc """
  Adds OAuth 1.0a Authorization header for user-context write access.

  Uses HMAC-SHA1 signing with consumer key/secret and access token/secret.
  """
  @spec add_oauth_header(Lux.Lens.t()) :: Lux.Lens.t()
  def add_oauth_header(%Lux.Lens{} = lens) do
    oauth_header = build_oauth_header(lens.method, lens.url, %{})
    %{lens | headers: lens.headers ++ [{"Authorization", oauth_header}]}
  end

  @spec add_oauth_header(Plug.Conn.t()) :: Plug.Conn.t()
  def add_oauth_header(%Plug.Conn{} = conn) do
    method = conn.method |> String.downcase() |> String.to_atom()
    url = "https://api.twitter.com#{conn.request_path}"
    oauth_header = build_oauth_header(method, url, %{})
    Plug.Conn.put_req_header(conn, "authorization", oauth_header)
  end

  @doc """
  Builds an OAuth 1.0a Authorization header string.
  """
  def build_oauth_header(method, url, params) do
    consumer_key = get_config(:twitter_consumer_key)
    access_token = get_config(:twitter_access_token)
    nonce = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    timestamp = System.system_time(:second) |> Integer.to_string()

    oauth_params = %{
      "oauth_consumer_key" => consumer_key,
      "oauth_nonce" => nonce,
      "oauth_signature_method" => "HMAC-SHA1",
      "oauth_timestamp" => timestamp,
      "oauth_token" => access_token,
      "oauth_version" => "1.0"
    }

    all_params = Map.merge(params, oauth_params)
    signature = build_signature(method, url, all_params)
    oauth_params_with_sig = Map.put(oauth_params, "oauth_signature", signature)

    header_parts =
      oauth_params_with_sig
      |> Enum.sort_by(fn {k, _} -> k end)
      |> Enum.map(fn {k, v} -> ~s(#{URI.encode(k)}="#{URI.encode(v)}") end)
      |> Enum.join(", ")

    "OAuth #{header_parts}"
  end

  defp build_signature(method, url, params) do
    consumer_secret = get_config(:twitter_consumer_secret)
    token_secret = get_config(:twitter_access_token_secret)

    param_string =
      params
      |> Enum.sort_by(fn {k, _} -> k end)
      |> Enum.map(fn {k, v} -> "#{URI.encode(k)}=#{URI.encode(v)}" end)
      |> Enum.join("&")

    method_str = method |> Atom.to_string() |> String.upcase()
    base_string = "#{method_str}&#{URI.encode(url)}&#{URI.encode(param_string)}"
    signing_key = "#{URI.encode(consumer_secret)}&#{URI.encode(token_secret || "")}"

    :crypto.mac(:hmac, :sha, signing_key, base_string)
    |> Base.encode64()
  end

  defp get_bearer_token do
    get_config(:twitter) || get_config(:twitter_bearer_token)
  end

  defp get_config(key) do
    Application.get_env(:lux, :api_keys, [])[key] || System.get_env("TWITTER_BEARER_TOKEN")
  end
end
