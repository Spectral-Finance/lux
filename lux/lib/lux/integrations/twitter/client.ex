defmodule Lux.Integrations.Twitter.Client do
  @moduledoc """
  HTTP client for Twitter API v2 endpoints.
  Built on `Req` with support for Bearer token authentication,
  query parameters, mock plugs for testing, and structured error handling.
  """

  @default_endpoint "https://api.twitter.com/2"

  @type request_opts :: %{
          optional(:token) => String.t(),
          optional(:endpoint) => String.t(),
          optional(:params) => map() | keyword(),
          optional(:json) => map(),
          optional(:headers) => [{String.t(), String.t()}],
          optional(:plug) => {module(), term()} | term()
        }

  @doc """
  Executes an HTTP request against the Twitter API.
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    endpoint = Map.get(opts, :endpoint, @default_endpoint)
    token = Map.get(opts, :token) || get_configured_token()

    headers = [
      {"User-Agent", "Lux-Agent-Framework/1.0"},
      {"Content-Type", "application/json"}
    ]

    headers =
      if token && token != "" do
        [{"Authorization", "Bearer #{token}"} | headers]
      else
        headers
      end

    url = build_url(endpoint, path)

    req_opts =
      [
        method: method,
        url: url,
        headers: headers
      ]
      |> maybe_put(:json, Map.get(opts, :json))
      |> maybe_put(:params, Map.get(opts, :params))
      |> maybe_add_plug(Map.get(opts, :plug))

    req_opts
    |> Req.new()
    |> Req.request()
    |> case do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %{status: 429, headers: headers, body: body}} ->
        reset_epoch =
          Enum.find_value(headers, fn
            {k, v} when is_binary(k) ->
              if String.downcase(k) == "x-rate-limit-reset", do: String.to_integer(v), else: nil

            _ ->
              nil
          end)

        {:error, {:rate_limited, reset_epoch, body}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
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
