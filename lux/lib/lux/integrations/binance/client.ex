defmodule Lux.Integrations.Binance.Client do
  @moduledoc """
  HTTP client for Binance REST API requests.

  Handles both public (unsigned) and private (HMAC-SHA256 signed) endpoints.
  """

  require Logger

  @base_url "https://api.binance.com"

  @type request_opts :: %{
    optional(:api_key) => String.t(),
    optional(:secret_key) => String.t(),
    optional(:params) => map(),
    optional(:json) => map(),
    optional(:signed) => boolean(),
    optional(:plug) => {module(), term()}
  }

  @doc """
  Makes a request to the Binance REST API.

  For signed endpoints, pass `signed: true` in opts — the client will
  append `timestamp` and `signature` query parameters automatically.

  ## Examples

      iex> Client.request(:get, "/api/v3/ticker/price", %{params: %{symbol: "BTCUSDT"}})
      {:ok, %{"symbol" => "BTCUSDT", "price" => "50000.00"}}

      iex> Client.request(:post, "/api/v3/order", %{
      ...>   signed: true,
      ...>   api_key: "key",
      ...>   secret_key: "secret",
      ...>   params: %{symbol: "BTCUSDT", side: "BUY", type: "MARKET", quantity: "0.001"}
      ...> })
      {:ok, %{"orderId" => 12345, "status" => "FILLED"}}
  """
  @spec request(atom(), String.t(), request_opts()) :: {:ok, map() | list()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    api_key = opts[:api_key] || get_config(:api_key)
    secret_key = opts[:secret_key] || get_config(:secret_key)
    signed = Map.get(opts, :signed, false)

    params = build_params(opts[:params] || %{}, signed, secret_key)
    url = @base_url <> path

    headers = [{"Content-Type", "application/json"}]
    headers = if api_key, do: [{"X-MBX-APIKEY", api_key} | headers], else: headers

    [
      method: method,
      url: url,
      headers: headers,
      params: params
    ]
    |> maybe_add_json(opts[:json])
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(opts[:plug])
    |> Req.new()
    |> Req.request()
    |> handle_response()
  end

  defp build_params(params, false, _secret), do: params

  defp build_params(params, true, secret_key) do
    timestamp = :os.system_time(:millisecond)
    params_with_ts = Map.put(params, :timestamp, timestamp)
    query_string = URI.encode_query(params_with_ts)
    signature = sign(query_string, secret_key)
    Map.put(params_with_ts, :signature, signature)
  end

  defp sign(query_string, secret_key) do
    :crypto.mac(:hmac, :sha256, secret_key, query_string)
    |> Base.encode16(case: :lower)
  end

  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: 400, body: %{"code" => code, "msg" => msg}}}) do
    {:error, {:bad_request, code, msg}}
  end

  defp handle_response({:ok, %{status: 401, body: %{"code" => code, "msg" => msg}}}) do
    {:error, {:unauthorized, code, msg}}
  end

  defp handle_response({:ok, %{status: 429}}) do
    {:error, :rate_limited}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    {:error, {status, body}}
  end

  defp handle_response({:error, error}) do
    {:error, error}
  end

  defp maybe_add_json(options, nil), do: options
  defp maybe_add_json(options, json), do: Keyword.put(options, :json, json)

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)

  defp get_config(key) do
    Application.get_env(:lux, :binance, [])
    |> Keyword.get(key)
  end
end
