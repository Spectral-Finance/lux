defmodule Lux.Integrations.Coinbase do
  @moduledoc "Coinbase exchange integration using Advanced Trade API (v3) with JWT Bearer auth."
  @base_url "https://api.coinbase.com"

  def ticker(product_id), do: get("/api/v3/brokerage/market/productbook", %{product_id: product_id, limit: 1})
  def order_book(product_id, limit \\ 100), do: get("/api/v3/brokerage/market/productbook", %{product_id: product_id, limit: limit})
  def trades(product_id, limit \\ 100), do: get("/api/v3/brokerage/market/trades", %{product_id: product_id, limit: limit})
  def products, do: get("/api/v3/brokerage/market/products", %{})
  def accounts, do: signed_get("/api/v3/brokerage/accounts", %{})
  def order(product_id, side, qty), do: signed_post("/api/v3/brokerage/orders", %{product_id: product_id, side: side, order_configuration: %{market_market_ioc: %{quote_size: qty}}})

  defp get(path, params), do: request(:get, path, params, false)
  defp signed_get(path, params), do: request(:get, path, params, true)
  defp signed_post(path, params), do: request(:post, path, params, true)

  defp request(method, path, params, signed) do
    url = @base_url <> path
    headers = [{"Content-Type", "application/json"}]
    headers = if signed, do: [{"Authorization", "Bearer #{jwt_token()}"} | headers], else: headers
    opts = [url: url, headers: headers, receive_timeout: 10_000]
    opts = if method == :post, do: Keyword.put(opts, :json, params), else: Keyword.put(opts, :params, params)
    req = Req.new(opts)
    case Req.request(req, method: method) do
      {:ok, %{status: 200, body: b}} -> {:ok, b}
      {:ok, %{status: s, body: b}} -> {:error, {s, b}}
      {:error, err} -> {:error, err}
    end
  end

  defp jwt_token, do: Application.get_env(:lux, :coinbase_jwt_token) || ""
end
