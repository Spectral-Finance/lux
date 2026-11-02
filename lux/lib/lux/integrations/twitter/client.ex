defmodule Lux.Integrations.Twitter.Client do
  @moduledoc """
  HTTP client for Twitter API v2 and v1.1 endpoints.
  Built on `Req` with support for OAuth Bearer authentication,
  query parameter encoding, JSON payloads, custom plugs (for testing),
  and structured error handling.
  """

  require Logger

  @default_endpoint "https://api.twitter.com/2"

  @type request_opts :: %{
          optional(:token) => String.t(),
          optional(:endpoint) => String.t(),
          optional(:params) => map() | keyword(),
          optional(:json) => map(),
          optional(:body) => term(),
          optional(:headers) => [{String.t(), String.t()}],
          optional(:plug) => {module(), term()} | term()
        }

  @doc """
  Executes an HTTP request against the Twitter API.

  ## Parameters
    * `method` - `:get`, `:post`, `:put`, or `:delete`
    * `path` - Endpoint path (e.g. `"/tweets"`, `"/users/me"`)
    * `opts` - Options map including `:token`, `:json`, `:params`, `:headers`, `:plug`
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    endpoint = Map.get(opts, :endpoint, @default_endpoint)
    token = Map.get(opts, :token) || get_configured_token()

    base_headers = [
      {"User-Agent", "Lux-Agent-Framework/1.0"}
    ]

    auth_headers =
      if token && token != "" do
        [{"Authorization", "Bearer #{token}"}]
      else
        []
      end

    content_headers =
      if Map.has_key?(opts, :json) do
        [{"Content-Type", "application/json"}]
      else
        []
      end

    extra_headers = Map.get(opts, :headers, [])
    headers = base_headers ++ auth_headers ++ content_headers ++ extra_headers

    url = build_url(endpoint, path)

    req_opts =
      [
        method: method,
        url: url,
        headers: headers
      ]
      |> maybe_put(:json, Map.get(opts, :json))
      |> maybe_put(:body, Map.get(opts, :body))
      |> maybe_put(:params, Map.get(opts, :params))
      |> maybe_add_plug(Map.get(opts, :plug))

    req_opts
    |> Req.new()
    |> Req.request()
    |> handle_response()
  end

  defp build_url(endpoint, path) do
    if String.starts_with?(path, "http://") or String.starts_with?(path, "https://") do
      path
    else
      endpoint = String.trim_trailing(endpoint, "/")
      path = if String.starts_with?(path, "/"), do: path, else: "/" <> path
      endpoint <> path
    end
  end

  defp handle_response({:ok, %{status: status, body: body} = response}) when status in 200..299 do
    rate_limit_meta = extract_rate_limit_headers(response.headers)

    parsed_body =
      case body do
        %{} = map ->
          if map_size(rate_limit_meta) > 0 do
            Map.put(map, "_rate_limit", rate_limit_meta)
          else
            map
          end

        other ->
          other
      end

    {:ok, parsed_body}
  end

  defp handle_response({:ok, %{status: 401}}) do
    {:error, :unauthorized}
  end

  defp handle_response({:ok, %{status: 403, body: body}}) do
    {:error, {:forbidden, body}}
  end

  defp handle_response({:ok, %{status: 404, body: body}}) do
    {:error, {:not_found, body}}
  end

  defp handle_response({:ok, %{status: 429, headers: headers, body: body}}) do
    reset_epoch =
      Enum.find_value(headers, fn
        {k, v} when is_binary(k) ->
          if String.downcase(k) == "x-rate-limit-reset", do: String.to_integer(v), else: nil

        _ ->
          nil
      end)

    {:error, {:rate_limited, reset_epoch, body}}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    {:error, {status, body}}
  end

  defp handle_response({:error, reason}) do
    {:error, reason}
  end

  defp extract_rate_limit_headers(headers) when is_list(headers) do
    headers
    |> Enum.reduce(%{}, fn {k, v}, acc ->
      case String.downcase(to_string(k)) do
        "x-rate-limit-limit" -> Map.put(acc, :limit, parse_int(v))
        "x-rate-limit-remaining" -> Map.put(acc, :remaining, parse_int(v))
        "x-rate-limit-reset" -> Map.put(acc, :reset, parse_int(v))
        _ -> acc
      end
    end)
  end

  defp extract_rate_limit_headers(_), do: %{}

  defp parse_int(val) when is_integer(val), do: val

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_int(_), do: nil

  defp maybe_put(keyword, _key, nil), do: keyword
  defp maybe_put(keyword, key, value), do: Keyword.put(keyword, key, value)

  defp maybe_add_plug(keyword, nil), do: keyword
  defp maybe_add_plug(keyword, plug), do: Keyword.put(keyword, :plug, plug)

  defp get_configured_token do
    case Application.get_env(:lux, :api_keys) do
      nil -> System.get_env("TWITTER_BEARER_TOKEN") || ""
      keys -> Keyword.get(keys, :twitter_bearer_token, System.get_env("TWITTER_BEARER_TOKEN") || "")
    end
  end
end
