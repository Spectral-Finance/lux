defmodule Lux.Integrations.Coinbase.Client do
  @moduledoc """
  HTTP client for Coinbase Advanced Trade API with HMAC-SHA256 authentication.
  """

  require Logger

  @endpoint "https://api.coinbase.com/api/v3/brokerage"

  @spec request(atom(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    api_key = opts[:api_key] || Lux.Integrations.Coinbase.coinbase_api_key()
    api_secret = opts[:api_secret] || Lux.Integrations.Coinbase.coinbase_api_secret()
    timestamp = Integer.to_string(System.system_time(:second))
    method_str = method |> to_string() |> String.upcase()
    body = if opts[:json], do: Jason.encode!(opts[:json]), else: ""
    message = timestamp <> method_str <> "/api/v3/brokerage" <> path <> body
    signature = Lux.Integrations.Coinbase.sign(message, api_secret)

    [
      method: method,
      url: @endpoint <> path,
      headers: [
        {"CB-ACCESS-KEY", api_key},
        {"CB-ACCESS-SIGN", signature},
        {"CB-ACCESS-TIMESTAMP", timestamp},
        {"Content-Type", "application/json"}
      ]
    ]
    |> maybe_add_body(opts[:json])
    |> maybe_add_params(opts[:params])
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(opts[:plug])
    |> Req.new()
    |> Req.request()
    |> handle_response()
  end

  defp handle_response({:ok, %{status: status} = resp}) when status in 200..299, do: {:ok, resp.body}
  defp handle_response({:ok, %{status: 401}}), do: {:error, :invalid_credentials}
  defp handle_response({:ok, %{status: 429}}), do: {:error, :rate_limited}
  defp handle_response({:ok, %{status: s, body: %{"error" => e, "message" => m}}}), do: {:error, {s, "#{e}: #{m}"}}
  defp handle_response({:ok, %{status: s, body: %{"message" => m}}}), do: {:error, {s, m}}
  defp handle_response({:ok, %{status: s, body: b}}), do: {:error, {s, b}}
  defp handle_response({:error, e}), do: {:error, e}

  defp maybe_add_body(opts, nil), do: opts
  defp maybe_add_body(opts, json), do: Keyword.put(opts, :json, json)
  defp maybe_add_params(opts, nil), do: opts
  defp maybe_add_params(opts, params), do: Keyword.put(opts, :params, params)
  defp maybe_add_plug(opts, nil), do: opts
  defp maybe_add_plug(opts, plug), do: Keyword.put(opts, :plug, plug)
end
