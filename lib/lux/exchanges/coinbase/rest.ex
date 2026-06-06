defmodule Lux.Exchanges.Coinbase.Rest do
  @moduledoc """
  REST API client for Coinbase Advanced Trade API.
  """

  use Tesla

  @base_url "https://api.exchange.coinbase.com"
  @sandbox_url "https://api-public.sandbox.exchange.coinbase.com"

  plug Tesla.Middleware.BaseUrl, @base_url
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Headers, [{"User-Agent", "lux-coinbase-client"}]
  plug Tesla.Middleware.Retry, delay: 1000, max_retries: 3
  plug Tesla.Middleware.Logger, log_level: :info

  alias Lux.Exchanges.Coinbase.Auth

  @doc """
  Makes an authenticated GET request to the Coinbase API.
  """
  def get(path, params \\ []) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    headers = Auth.sign_request("GET", path, "", timestamp)

    Tesla.get(client(), path, query: params, headers: headers)
    |> handle_response()
  end

  @doc """
  Makes an authenticated POST request to the Coinbase API.
  """
  def post(path, body \\ %{}) do
    body_json = Jason.encode!(body)
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    headers = Auth.sign_request("POST", path, body_json, timestamp)

    Tesla.post(client(), path, body_json, headers: headers)
    |> handle_response()
  end

  @doc """
  Makes an authenticated DELETE request to the Coinbase API.
  """
  def delete(path) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    headers = Auth.sign_request("DELETE", path, "", timestamp)

    Tesla.delete(client(), path, headers: headers)
    |> handle_response()
  end

  @doc """
  Gets account information.
  """
  def get_accounts do
    get("/accounts")
  end

  @doc """
  Gets a specific account by ID.
  """
  def get_account(account_id) do
    get("/accounts/#{account_id}")
  end

  @doc """
  Gets all open orders.
  """
  def get_orders(params \\ []) do
    get("/orders", params)
  end

  @doc """
  Gets a specific order by ID.
  """
  def get_order(order_id) do
    get("/orders/#{order_id}")
  end

  @doc """
  Places a new order.
  """
  def place_order(order_params) do
    post("/orders", order_params)
  end

  @doc """
  Cancels an order.
  """
  def cancel_order(order_id) do
    delete("/orders/#{order_id}")
  end

  @doc """
  Gets fills (executed orders).
  """
  def get_fills(params \\ []) do
    get("/fills", params)
  end

  @doc """
  Gets products (trading pairs).
  """
  def get_products do
    get("/products")
  end

  @doc """
  Gets ticker information for a product.
  """
  def get_ticker(product_id) do
    get("/products/#{product_id}/ticker")
  end

  @doc """
  Gets order book for a product.
  """
  def get_order_book(product_id, level \\ 1) do
    get("/products/#{product_id}/book", level: level)
  end

  @doc """
  Gets trades for a product.
  """
  def get_trades(product_id, params \\ []) do
    get("/products/#{product_id}/trades", params)
  end

  @doc """
  Gets candles (OHLCV) for a product.
  """
  def get_candles(product_id, params \\ []) do
    get("/products/#{product_id}/candles", params)
  end

  @doc """
  Gets 24hr stats for a product.
  """
  def get_stats(product_id) do
    get("/products/#{product_id}/stats")
  end

  @doc """
  Gets currencies.
  """
  def get_currencies do
    get("/currencies")
  end

  @doc """
  Gets exchange time.
  """
  def get_time do
    get("/time")
  end

  defp client do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, get_base_url()},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers, [{"User-Agent", "lux-coinbase-client"}]},
      Tesla.Middleware.Retry,
      Tesla.Middleware.Logger
    ])
  end

  defp get_base_url do
    if Application.get_env(:lux, :coinbase_sandbox, false) do
      @sandbox_url
    else
      @base_url
    end
  end

  defp handle_response({:ok, %Tesla.Env{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %Tesla.Env{status: 429, body: body}}) do
    {:error, :rate_limited, body}
  end

  defp handle_response({:ok, %Tesla.Env{status: status, body: body}}) do
    {:error, :api_error, %{status: status, body: body}}
  end

  defp handle_response({:error, reason}) do
    {:error, :network_error, reason}
  end
end