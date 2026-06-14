
defmodule Lux.Integrations.Binance do
  @moduledoc """
  Binance exchange integration for spot trading and market data.
  """
  @base_url "https://api.binance.com"

  def ticker(symbol), do: get("/api/v3/ticker/24hr", %{symbol: String.upcase(symbol)})
  def order_book(symbol, limit \\ 100), do: get("/api/v3/depth", %{symbol: String.upcase(symbol), limit: limit})
  def recent_trades(symbol, limit \\ 100), do: get("/api/v3/trades", %{symbol: String.upcase(symbol), limit: limit})
  def klines(symbol, interval, limit \\ 100), do: get("/api/v3/klines", %{symbol: String.upcase(symbol), interval: interval, limit: limit})
  def exchange_info, do: get("/api/v3/exchangeInfo", %{})

  def account_info, do: signed_get("/api/v3/account", %{})
  def open_orders(symbol), do: signed_get("/api/v3/openOrders", %{symbol: String.upcase(symbol)})

  def market_order(symbol, side, qty) do
    signed_post("/api/v3/order", %{symbol: String.upcase(symbol), side: String.upcase(side), type: "MARKET", quantity: qty})
  end

  def limit_order(symbol, side, qty, price) do
    signed_post("/api/v3/order", %{symbol: String.upcase(symbol), side: String.upcase(side), type: "LIMIT", timeInForce: "GTC", quantity: qty, price: price})
  end

  def cancel_order(symbol, order_id), do: signed_delete("/api/v3/order", %{symbol: String.upcase(symbol), orderId: order_id})

  defp get(path, params), do: request(:get, path, params, false)
  defp signed_get(path, params), do: request(:get, path, params, true)
  defp signed_post(path, params), do: request(:post, path, params, true)
  defp signed_delete(path, params), do: request(:delete, path, params, true)

  defp request(method, path, params, signed) do
    params = if signed, do: sign_params(params), else: params
    url = @base_url <> path <> (if params != %{}, do: "?" <> URI.encode_query(params), else: "")

    req = Req.new(url: url, headers: [{"Content-Type", "application/json"}])
    req = if signed, do: Req.put_header(req, "X-MBX-APIKEY", api_key()), else: req

    case Req.request(req, method: method) do
      {:ok, %{status: 200, body: b}} -> {:ok, b}
      {:ok, %{status: s, body: %{"msg" => m}}} -> {:error, {s, m}}
      {:ok, %{status: s}} -> {:error, {s, "HTTP #{s}"}}
      {:error, e} -> {:error, inspect(e)}
    end
  end

  defp api_key, do: Application.get_env(:lux, Lux.Integrations.Binance)[:api_key] || Application.get_env(:lux, :binance_api_key)
  defp secret_key, do: Application.get_env(:lux, Lux.Integrations.Binance)[:secret_key] || Application.get_env(:lux, :binance_secret_key)

  defp sign_params(params) do
    ts = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    q = URI.encode_query(Map.put(params, :timestamp, ts))
    sig = :crypto.hmac(:sha256, secret_key(), q) |> Base.encode16(case: :lower)
    Map.put(params, :timestamp, ts) |> Map.put(:signature, sig)
  end
end
