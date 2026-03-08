defmodule Lux.Integrations.Binance.Client do
  @moduledoc """
  HTTP client for Binance API requests with HMAC-SHA256 request signing.
  """

  alias Lux.Integrations.Binance

  @type request_opts :: %{
    optional(:params) => map(),
    optional(:json) => map(),
    optional(:signed) => boolean(),
    optional(:futures) => boolean(),
    optional(:api_key) => String.t(),
    optional(:secret_key) => String.t(),
    optional(:plug) => {module(), term()}
  }

  @spec request(atom(), String.t(), request_opts()) :: {:ok, map() | list()} | {:error, term()}
  def request(method, path, opts \\ %{}) do
    api_key = opts[:api_key] || Binance.api_key()
    secret_key = opts[:secret_key] || Binance.secret_key()
    signed = opts[:signed] || false
    futures = opts[:futures] || false
    params = opts[:params] || %{}
    base_url = if futures, do: Binance.futures_base_url(), else: Binance.spot_base_url()

    {_qs, url} = build_url(base_url, path, params, signed, secret_key)

    [method: method, url: url, headers: [{"X-MBX-APIKEY", api_key}, {"Content-Type", "application/json"}], retry: false]
    |> maybe_add_json(opts[:json])
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(opts[:plug])
    |> Req.new()
    |> Req.request()
    |> handle_response()
  end

  defp build_url(base_url, path, params, true, secret_key) do
    params = Map.put(params, :timestamp, Binance.timestamp())
    qs = URI.encode_query(params)
    sig = Binance.sign(qs, secret_key)
    signed_qs = "#{qs}&signature=#{sig}"
    {signed_qs, "#{base_url}#{path}?#{signed_qs}"}
  end

  defp build_url(base_url, path, params, false, _secret_key) do
    if map_size(params) > 0 do
      qs = URI.encode_query(params)
      {qs, "#{base_url}#{path}?#{qs}"}
    else
      {"", "#{base_url}#{path}"}
    end
  end

  defp maybe_add_json(opts, nil), do: opts
  defp maybe_add_json(opts, json), do: Keyword.put(opts, :json, json)

  defp maybe_add_plug(opts, nil), do: opts
  defp maybe_add_plug(opts, plug), do: Keyword.put(opts, :plug, plug)

  defp handle_response({:ok, %{status: s, body: body}}) when s in 200..299, do: {:ok, body}
  defp handle_response({:ok, %{status: 429, body: body}}), do: {:error, {:rate_limited, get_msg(body)}}
  defp handle_response({:ok, %{status: 418, body: body}}), do: {:error, {:ip_banned, get_msg(body)}}
  defp handle_response({:ok, %{status: s, body: body}}), do: {:error, {s, get_msg(body)}}
  defp handle_response({:error, error}), do: {:error, error}

  defp get_msg(%{"msg" => m}), do: m
  defp get_msg(b) when is_binary(b), do: b
  defp get_msg(b), do: inspect(b)
end
