defmodule Lux.Integrations.Twitter.Client do
  @moduledoc """
  HTTP client for Twitter API v2 requests.

  Handles authentication, rate limiting, and error responses
  for all Twitter API v2 endpoints.

  ## Authentication Methods

  - `:bearer` — OAuth 2.0 Bearer Token (app-only, read endpoints)
  - `:oauth1` — OAuth 1.0a User Context (write endpoints)

  ## Rate Limiting

  Twitter API v2 has strict rate limits. This client:
  - Tracks rate limit headers (x-rate-limit-remaining, x-rate-limit-reset)
  - Returns rate limit info in error responses
  - Supports automatic retry with backoff

  ## Examples

      # Read with bearer token
      Client.request(:get, "/tweets/123", %{token: "bearer_token"})

      # Post with OAuth 1.0a
      Client.request(:post, "/tweets", %{
        auth_type: :oauth1,
        api_key: "key",
        api_secret: "secret",
        access_token: "token",
        access_secret: "secret",
        json: %{text: "Hello from Lux!"}
      })
  """

  require Logger

  @endpoint "https://api.twitter.com/2"
  @upload_endpoint "https://upload.twitter.com/1.1"

  @type auth_type :: :bearer | :oauth1
  @type request_opts :: %{
          optional(:token) => String.t(),
          optional(:auth_type) => auth_type(),
          optional(:api_key) => String.t(),
          optional(:api_secret) => String.t(),
          optional(:access_token) => String.t(),
          optional(:access_secret) => String.t(),
          optional(:json) => map(),
          optional(:params) => map(),
          optional(:headers) => [{String.t(), String.t()}],
          optional(:plug) => {module(), term()},
          optional(:base_url) => String.t()
        }

  @doc """
  Makes a request to the Twitter API v2.
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    auth_type = opts[:auth_type] || :bearer
    base_url = opts[:base_url] || @endpoint

    auth_header = build_auth_header(auth_type, method, base_url <> path, opts)

    req_opts =
      [
        method: method,
        url: base_url <> path,
        headers: [
          auth_header,
          {"Content-Type", "application/json"}
        ] ++ (opts[:headers] || [])
      ]
      |> maybe_add_json(opts[:json])
      |> maybe_add_params(opts[:params])
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
      |> maybe_add_plug(opts[:plug])

    req_opts
    |> Req.new()
    |> Req.request()
    |> handle_response()
  end

  @doc """
  Makes a media upload request to the Twitter v1.1 upload endpoint.
  """
  @spec upload(binary(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def upload(media_data, media_type, opts \\ %{}) do
    auth_type = opts[:auth_type] || :oauth1
    url = "#{@upload_endpoint}/media/upload.json"

    auth_header = build_auth_header(auth_type, :post, url, opts)

    # Use multipart for media upload
    multipart =
      Multipart.new()
      |> Multipart.add_part(Multipart.Part.binary_body(media_data, [
        {"content-disposition", "form-data; name=\"media_data\""},
        {"content-type", media_type}
      ]))
      |> Multipart.add_part(Multipart.Part.text_body(media_type, [
        {"content-disposition", "form-data; name=\"media_category\""}
      ]))

    [
      method: :post,
      url: url,
      headers: [auth_header],
      body: Multipart.body(multipart),
      headers: Multipart.headers(multipart) ++ [auth_header]
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(opts[:plug])
    |> Req.new()
    |> Req.request()
    |> handle_response()
  end

  # ─── Private ──────────────────────────────────────────────────────────────

  defp build_auth_header(:bearer, _method, _url, opts) do
    token = opts[:token] || Lux.Integrations.Twitter.bearer_token()
    {"Authorization", "Bearer #{token}"}
  end

  defp build_auth_header(:oauth1, method, url, opts) do
    api_key = opts[:api_key] || get_config(:twitter_api_key)
    api_secret = opts[:api_secret] || get_config(:twitter_api_secret)
    access_token = opts[:access_token] || get_config(:twitter_access_token)
    access_secret = opts[:access_secret] || get_config(:twitter_access_secret)

    # Generate OAuth 1.0a signature
    timestamp = :os.system_time(:second) |> to_string()
    nonce = :crypto.strong_rand_bytes(16) |> Base.hex_encode32(case: :lower) |> String.slice(0, 32)

    oauth_params = %{
      "oauth_consumer_key" => api_key,
      "oauth_nonce" => nonce,
      "oauth_signature_method" => "HMAC-SHA1",
      "oauth_timestamp" => timestamp,
      "oauth_token" => access_token,
      "oauth_version" => "1.0"
    }

    # Create signature base string
    method_str = method |> to_string() |> String.upcase()
    params_str = oauth_params |> Enum.sort() |> URI.encode_query()
    base_string = "#{method_str}&#{URI.encode_www_form(url)}&#{URI.encode_www_form(params_str)}"

    # Sign
    signing_key = "#{URI.encode_www_form(api_secret)}&#{URI.encode_www_form(access_secret)}"
    signature = :crypto.mac(:hmac, :sha, signing_key, base_string) |> Base.encode64()

    # Build Authorization header
    oauth_with_sig = Map.put(oauth_params, "oauth_signature", signature)

    header_value =
      oauth_with_sig
      |> Enum.sort()
      |> Enum.map(fn {k, v} -> "#{k}=\"#{URI.encode_www_form(v)}\"" end)
      |> Enum.join(", ")

    {"Authorization", "OAuth #{header_value}"}
  end

  defp handle_response({:ok, %{status: status, body: body, headers: headers}})
       when status in 200..299 do
    rate_limit = extract_rate_limit(headers)

    case body do
      %{"data" => data} -> {:ok, %{data: data, rate_limit: rate_limit}}
      data when is_map(data) -> {:ok, %{data: data, rate_limit: rate_limit}}
      _ -> {:ok, %{data: body, rate_limit: rate_limit}}
    end
  end

  defp handle_response({:ok, %{status: 401}}) do
    {:error, :unauthorized}
  end

  defp handle_response({:ok, %{status: 403}}) do
    {:error, :forbidden}
  end

  defp handle_response({:ok, %{status: 429, headers: headers}}) do
    reset_at = extract_rate_limit(headers)[:reset_at]
    {:error, {:rate_limited, reset_at}}
  end

  defp handle_response({:ok, %{status: status, body: %{"errors" => [%{"message" => msg} | _]}}}) do
    {:error, {status, msg}}
  end

  defp handle_response({:ok, %{status: status, body: %{"detail" => detail}}}) do
    {:error, {status, detail}}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    {:error, {status, inspect(body)}}
  end

  defp handle_response({:error, error}) do
    Logger.error("Twitter API request failed: #{inspect(error)}")
    {:error, error}
  end

  defp extract_rate_limit(headers) do
    headers_map = Map.new(headers, fn {k, v} -> {String.downcase(k), v} end)

    %{
      remaining: headers_map["x-rate-limit-remaining"] |> parse_int(),
      limit: headers_map["x-rate-limit-limit"] |> parse_int(),
      reset_at: headers_map["x-rate-limit-reset"] |> parse_int()
    }
  end

  defp parse_int(nil), do: nil
  defp parse_int(val) when is_binary(val), do: String.to_integer(val)
  defp parse_int(val), do: val

  defp maybe_add_json(opts, nil), do: opts
  defp maybe_add_json(opts, json), do: Keyword.put(opts, :json, json)

  defp maybe_add_params(opts, nil), do: opts
  defp maybe_add_params(opts, params), do: Keyword.put(opts, :params, params)

  defp maybe_add_plug(opts, nil), do: opts
  defp maybe_add_plug(opts, plug), do: Keyword.put(opts, :plug, plug)

  defp get_config(key) do
    Application.get_env(:lux, :api_keys)[key]
  end
end
