defmodule Lux.Integrations.Coinbase do
  @moduledoc """
  Integration with the Coinbase Exchange API for spot trading and advanced order management.

  Coinbase is a regulated US-based exchange providing REST and WebSocket APIs for
  trading, market data, portfolio management, and account operations.

  ## Configuration

  The following configuration is required in your `config/runtime.exs`:

      config :lux, Lux.Integrations.Coinbase,
        api_key: System.get_env("COINBASE_API_KEY"),
        api_secret: System.get_env("COINBASE_API_SECRET"),
        passphrase: System.get_env("COINBASE_PASSPHRASE"),
        base_url: System.get_env("COINBASE_BASE_URL") || "https://api.pro.coinbase.com",
        ws_url: System.get_env("COINBASE_WS_URL") || "wss://ws-feed.pro.coinbase.com"

  And in your environment:

      COINBASE_API_KEY=your_api_key
      COINBASE_API_SECRET=your_api_secret
      COINBASE_PASSPHRASE=your_passphrase
  """

  @base_url Application.compile_env(:lux, [__MODULE__, :base_url], "https://api.pro.coinbase.com")
  @ws_url Application.compile_env(:lux, [__MODULE__, :ws_url], "wss://ws-feed.pro.coinbase.com")

  # ─── Request Settings ────────────────────────────────────

  @doc """
  Common request settings for Coinbase API calls.
  Requires CB-ACCESS-KEY, CB-ACCESS-SIGN, CB-ACCESS-TIMESTAMP, CB-ACCESS-PASSPHRASE headers.
  """
  def request_settings do
    %{
      headers: [{"Content-Type", "application/json"}],
      auth: %{
        type: :custom,
        auth_function: &__MODULE__.add_auth_headers/1
      }
    }
  end

  @doc """
  Adds Coinbase authentication headers to the request.
  Signs the request with HMAC-SHA256 using the API secret.
  """
  def add_auth_headers(opts) do
    timestamp = System.system_time(:second) |> Integer.to_string()
    method = opts[:method] || "GET"
    path = opts[:path] || "/"
    body = opts[:body] || ""

    message = timestamp <> method <> path <> body
    signature = sign_request(message)

    [
      {"CB-ACCESS-KEY", api_key()},
      {"CB-ACCESS-SIGN", signature},
      {"CB-ACCESS-TIMESTAMP", timestamp},
      {"CB-ACCESS-PASSPHRASE", passphrase()},
      {"Content-Type", "application/json"}
    ]
  end

  # ─── REST API ─────────────────────────────────────────────

  @doc """
  Get all accounts/portfolios.
  """
  def get_accounts do
    request(:get, "/accounts")
  end

  @doc """
  Get account by ID.
  """
  def get_account(account_id) do
    request(:get, "/accounts/" <> account_id)
  end

  @doc """
  Get product order book.
  """
  def get_order_book(product_id, level \\ 2) do
    request(:get, "/products/" <> product_id <> "/book?level=" <> Integer.to_string(level))
  end

  @doc """
  Get product ticker.
  """
  def get_ticker(product_id) do
    request(:get, "/products/" <> product_id <> "/ticker")
  end

  @doc """
  Get product trades.
  """
  def get_trades(product_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    request(:get, "/products/" <> product_id <> "/trades?limit=" <> Integer.to_string(limit))
  end

  @doc """
  Get historical rates (candles).
  """
  def get_candles(product_id, opts \\ []) do
    granularity = Keyword.get(opts, :granularity, 3600)
    start_time = Keyword.get(opts, :start_time)
    end_time = Keyword.get(opts, :end_time)

    params = ["granularity=" <> Integer.to_string(granularity)]
    params = if start_time, do: ["start=" <> start_time | params], else: params
    params = if end_time, do: ["end=" <> end_time | params], else: params

    request(:get, "/products/" <> product_id <> "/candles?" <> Enum.join(params, "&"))
  end

  @doc """
  Get product stats (24h overview).
  """
  def get_stats(product_id) do
    request(:get, "/products/" <> product_id <> "/stats")
  end

  @doc """
  Get all available products.
  """
  def get_products do
    request(:get, "/products")
  end

  # ─── Order Management ────────────────────────────────────

  @doc """
  Place a new order.

  ## Parameters
    - product_id: e.g. "BTC-USD"
    - side: "buy" or "sell"
    - type: "limit", "market", or "stop"
    - opts: additional options (price, size, stop_price, etc.)
  """
  def place_order(product_id, side, type, opts \\ []) do
    body = %{
      product_id: product_id,
      side: side,
      type: type
    }
    |> merge_opts(opts)
    |> Jason.encode!()

    request(:post, "/orders", body)
  end

  @doc """
  Place a limit order.
  """
  def limit_order(product_id, side, price, size, opts \\ []) do
    place_order(product_id, side, "limit", [{:price, price}, {:size, size} | opts])
  end

  @doc """
  Place a market order.
  """
  def market_order(product_id, side, size_or_funds, opts \\ []) do
    opts = if opts[:size] || size_or_funds[:size] do
      [{:size, size_or_funds} | opts]
    else
      [{:funds, size_or_funds} | opts]
    end
    place_order(product_id, side, "market", opts)
  end

  @doc """
  Cancel an order by ID.
  """
  def cancel_order(order_id) do
    request(:delete, "/orders/" <> order_id)
  end

  @doc """
  Cancel all open orders, optionally filtered by product_id.
  """
  def cancel_all_orders(product_id \\ nil) do
    path = if product_id, do: "/orders?product_id=" <> product_id, else: "/orders"
    request(:delete, path)
  end

  @doc """
  List open orders.
  """
  def list_orders(opts \\ []) do
    product_id = Keyword.get(opts, :product_id)
    status = Keyword.get(opts, :status, "open")
    path = "/orders?status=" <> status
    path = if product_id, do: path <> "&product_id=" <> product_id, else: path
    request(:get, path)
  end

  @doc """
  Get order by ID.
  """
  def get_order(order_id) do
    request(:get, "/orders/" <> order_id)
  end

  @doc """
  Get fills.
  """
  def get_fills(opts \\ []) do
    product_id = Keyword.get(opts, :product_id)
    order_id = Keyword.get(opts, :order_id)
    params = []
    params = if product_id, do: ["product_id=" <> product_id | params], else: params
    params = if order_id, do: ["order_id=" <> order_id | params], else: params
    path = if length(params) > 0, do: "/fills?" <> Enum.join(params, "&"), else: "/fills"
    request(:get, path)
  end

  # ─── Portfolio Tracking ──────────────────────────────────

  @doc """
  Get portfolio summary with balances and P&L.
  """
  def get_portfolio_summary do
    accounts = get_accounts()
    %{
      accounts: accounts,
      total_value: calculate_portfolio_value(accounts),
      currencies: extract_currency_balances(accounts)
    }
  end

  # ─── Historical Data ─────────────────────────────────────

  @doc """
  Get recent fills for tax/P&L tracking.
  """
  def get_recent_fills(days \\ 30) do
    start_time = DateTime.utc_now() |> DateTime.add(-days * 86400, :second) |> DateTime.to_iso8601()
    request(:get, "/fills?start_date=" <> URI.encode(start_time))
  end

  # ─── Rate Limiting ───────────────────────────────────────

  @doc """
  Get rate limit status from last response headers.
  Coinbase rate limits: 15 requests/sec for public, 5 for private.
  """
  def rate_limit_info do
    %{
      public_limit: 15,
      private_limit: 5,
      burst_allowance: 3
    }
  end

  # ─── WebSocket ────────────────────────────────────────────

  @doc """
  Build WebSocket subscription message for market data.
  """
  def ws_subscribe(product_ids, channels \\ ["ticker", "level2", "matches"]) do
    %{
      type: "subscribe",
      product_ids: List.wrap(product_ids),
      channels: channels
    }
    |> Jason.encode!()
  end

  @doc """
  Build WebSocket unsubscribe message.
  """
  def ws_unsubscribe(product_ids, channels) do
    %{
      type: "unsubscribe",
      product_ids: List.wrap(product_ids),
      channels: List.wrap(channels)
    }
    |> Jason.encode!()
  end

  # ─── Private Helpers ─────────────────────────────────────

  defp request(method, path, body \\ "") do
    headers = add_auth_headers(method: method_to_string(method), path: path, body: body)

    opts = [
      method: method,
      url: @base_url <> path,
      headers: headers
    ]

    opts = if body != "", do: Keyword.put(opts, :body, body), else: opts

    case HTTPoison.request(opts) do
      {:ok, %HTTPoison.Response{status_code: 200, body: resp_body}} ->
        Jason.decode(resp_body)

      {:ok, %HTTPoison.Response{status_code: status, body: resp_body}} ->
        {:error, %{status: status, body: resp_body}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp sign_request(message) do
    :crypto.mac(:hmac, :sha256, api_secret(), message)
    |> Base.encode64()
  end

  defp api_key, do: Application.get_env(:lux, __MODULE__)[:api_key]
  defp api_secret, do: Application.get_env(:lux, __MODULE__)[:api_secret]
  defp passphrase, do: Application.get_env(:lux, __MODULE__)[:passphrase]

  defp method_to_string(:get), do: "GET"
  defp method_to_string(:post), do: "POST"
  defp method_to_string(:put), do: "PUT"
  defp method_to_string(:delete), do: "DELETE"
  defp method_to_string(s), do: String.upcase(to_string(s))

  defp merge_opts(map, opts) do
    Enum.reduce(opts, map, fn {k, v}, acc -> Map.put(acc, k, v) end)
  end

  defp calculate_portfolio_value(accounts) when is_list(accounts) do
    Enum.reduce(accounts, 0.0, fn acc, total ->
      balance = String.to_float(acc["balance"] || "0.0")
      total + balance
    end)
  end
  defp calculate_portfolio_value(_), do: 0.0

  defp extract_currency_balances(accounts) when is_list(accounts) do
    Enum.map(accounts, fn acc ->
      %{currency: acc["currency"], balance: acc["balance"], available: acc["available"]}
    end)
  end
  defp extract_currency_balances(_), do: []
end
