defmodule Lux.Integrations.Binance.Client do
  @moduledoc """
  HTTP client for the Binance REST API.

  Handles all HTTP requests to Binance's spot and futures endpoints
  with HMAC SHA256 request signing for authenticated endpoints.
  Uses `Req` for robust HTTP client capabilities including retries,
  timeouts, and JSON encoding/decoding.

  ## API Endpoints

  Spot base URL: https://api.binance.com
  Futures base URL: https://fapi.binance.com

  ## Authentication

  Signed endpoints require:
  - `X-MBX-APIKEY` header with the API key
  - `signature` query parameter (HMAC SHA256 of query string)
  - `timestamp` query parameter (milliseconds since epoch)

  ## Examples

      # Get server time
      iex> Client.get_server_time(:spot)
      {:ok, %{"serverTime" => 1678901234567}}

      # Place a spot limit order
      iex> Client.place_order(:spot, %{
      ...>   symbol: "ETHUSDT",
      ...>   side: "BUY",
      ...>   type: "LIMIT",
      ...>   quantity: 0.1,
      ...>   price: 2800.0,
      ...>   time_in_force: "GTC"
      ...> })
      {:ok, %{"orderId" => 123456, ...}}
  """

  require Logger

  alias Lux.Config
  alias Lux.Integrations.Binance.RateLimiter

  @spot_base_url "https://api.binance.com"
  @futures_base_url "https://fapi.binance.com"

  @type market_type :: :spot | :futures
  @type request_opts :: %{
    optional(:plug) => {module(), term()},
    optional(:base_url) => String.t(),
    optional(:rate_limiter) => pid() | atom()
  }

  @doc """
  Tests connectivity to the Binance API.

  ## Parameters

    * `market` — `:spot` or `:futures`
    * `opts` — Optional request options
  """
  @spec ping(market_type(), request_opts()) :: {:ok, term()} | {:error, term()}
  def ping(market, opts \\ %{}) do
    path = if market == :futures, do: "/fapi/v1/ping", else: "/api/v3/ping"
    get(market, path, [], opts)
  end

  @doc """
  Gets the current server time from Binance.

  ## Parameters

    * `market` — `:spot` or `:futures`
    * `opts` — Optional request options
  """
  @spec get_server_time(market_type(), request_opts()) :: {:ok, term()} | {:error, term()}
  def get_server_time(market, opts \\ %{}) do
    path = if market == :futures, do: "/fapi/v1/time", else: "/api/v3/time"
    get(market, path, [], opts)
  end

  @doc """
  Gets exchange information including symbols, filters, and trading rules.

  ## Parameters

    * `market` — `:spot` or `:futures`
    * `opts` — Optional request options
  """
  @spec get_exchange_info(market_type(), request_opts()) :: {:ok, term()} | {:error, term()}
  def get_exchange_info(market, opts \\ %{}) do
    path = if market == :futures, do: "/fapi/v1/exchangeInfo", else: "/api/v3/exchangeInfo"
    get(market, path, [], opts)
  end

  @doc """
  Gets market information for a specific symbol.

  ## Parameters

    * `market` — `:spot` or `:futures`
    * `symbol` — Trading pair symbol (e.g., "ETHUSDT")
    * `opts` — Optional request options
  """
  @spec get_symbol_info(market_type(), String.t(), request_opts()) :: {:ok, term()} | {:error, term()}
  def get_symbol_info(market, symbol, opts \\ %{}) do
    path = if market == :futures, do: "/fapi/v1/exchangeInfo", else: "/api/v3/exchangeInfo"
    get(market, path, [symbol: symbol], opts)
  end

  @doc """
  Gets the order book for a symbol.

  ## Parameters

    * `market` — `:spot` or `:futures`
    * `symbol` — Trading pair symbol (e.g., "ETHUSDT")
    * `limit` — Number of levels (5, 10, 20, 50, 100, 500, 1000). Default: 100
    * `opts` — Optional request options
  """
  @spec get_order_book(market_type(), String.t(), integer(), request_opts()) :: {:ok, term()} | {:error, term()}
  def get_order_book(market, symbol, limit \\ 100, opts \\ %{}) do
    path = if market == :futures, do: "/fapi/v1/depth", else: "/api/v3/depth"
    get(market, path, [symbol: symbol, limit: limit], opts)
  end

  @doc """
  Gets recent trades for a symbol.

  ## Parameters

    * `market` — `:spot` or `:futures`
    * `symbol` — Trading pair symbol
    * `limit` — Number of trades (default: 500, max: 1000)
    * `opts` — Optional request options
  """
  @spec get_recent_trades(market_type(), String.t(), integer(), request_opts()) :: {:ok, term()} | {:error, term()}
  def get_recent_trades(market, symbol, limit \\ 500, opts \\ %{}) do
    path = if market == :futures, do: "/fapi/v1/trades", else: "/api/v3/trades"
    get(market, path, [symbol: symbol, limit: limit], opts)
  end

  @doc """
  Gets kline/candlestick data for a symbol.

  ## Parameters

    * `market` — `:spot` or `:futures`
    * `symbol` — Trading pair symbol
    * `interval` — Kline interval (1m, 5m, 15m, 1h, 4h, 1d, 1w, etc.)
    * `limit` — Number of klines (default: 500, max: 1000)
    * `opts` — Optional request options
  """
  @spec get_klines(market_type(), String.t(), String.t(), integer(), request_opts()) :: {:ok, term()} | {:error, term()}
  def get_klines(market, symbol, interval \\ "1h", limit \\ 500, opts \\ %{}) do
    path = if market == :futures, do: "/fapi/v1/klines", else: "/api/v3/klines"
    get(market, path, [symbol: symbol, interval: interval, limit: limit], opts)
  end

  @doc """
  Gets 24hr ticker price change statistics.

  ## Parameters

    * `market` — `:spot` or `:futures`
    * `symbol` — Trading pair symbol (optional; returns all if nil)
    * `opts` — Optional request options
  """
  @spec get_ticker(market_type(), String.t() | nil, request_opts()) :: {:ok, term()} | {:error, term()}
  def get_ticker(market, symbol \\ nil, opts \\ %{}) do
    path = if market == :futures, do: "/fapi/v1/ticker/24hr", else: "/api/v3/ticker/24hr"
    params = if symbol, do: [symbol: symbol], else: []
    get(market, path, params, opts)
  end

  @doc """
  Gets the current average price for a symbol.

  ## Parameters

    * `market` — `:spot` or `:futures`
    * `symbol` — Trading pair symbol
    * `opts` — Optional request options
  """
  @spec get_avg_price(market_type(), String.t(), request_opts()) :: {:ok, term()} | {:error, term()}
  def get_avg_price(market, symbol, opts \\ %{}) do
    path = if market == :futures, do: "/fapi/v1/avgPrice", else: "/api/v3/avgPrice"
    get(market, path, [symbol: symbol], opts)
  end

  @doc """
  Gets the current best price/qty on the order book.

  ## Parameters

    * `market` — `:spot` or `:futures`
    * `symbol` — Trading pair symbol
    * `opts` — Optional request options
  """
  @spec get_book_ticker(market_type(), String.t(), request_opts()) :: {:ok, term()} | {:error, term()}
  def get_book_ticker(market, symbol, opts \\ %{}) do
    path = if market == :futures, do: "/fapi/v1/ticker/bookTicker", else: "/api/v3/ticker/bookTicker"
    get(market, path, [symbol: symbol], opts)
  end

  @doc """
  Places a new order on Binance.

  ## Parameters

    * `market` — `:spot` or `:futures`
    * `params` — Order parameters map with keys:
      - `:symbol` — Trading pair
      - `:side` — "BUY" or "SELL"
      - `:type` — "LIMIT", "MARKET", "STOP_LOSS", "STOP_LOSS_LIMIT", "TAKE_PROFIT", etc.
      - `:quantity` — Order quantity
      - `:price` — Limit price (required for LIMIT orders)
      - `:time_in_force` — "GTC", "IOC", "FOK" (for LIMIT orders)
      - `:stop_price` — Stop price (for stop orders)
      - `:reduce_only` — Whether order only reduces position (futures)
      - `:position_side` — "LONG" or "SHORT" (futures hedge mode)
      - `:new_client_order_id` — Custom client order ID
    * `opts` — Optional request options
  """
  @spec place_order(market_type(), map(), request_opts()) :: {:ok, term()} | {:error, term()}
  def place_order(market, params, opts \\ %{}) do
    opts = normalize_opts(opts)

    with :ok <- sandbox_guard(),
         :ok <- check_rate_limit(opts[:rate_limiter], market) do
      do_place_order(market, params, opts)
    end
  end

  defp do_place_order(market, params, opts) do
    path = if market == :futures, do: "/fapi/v1/order", else: "/api/v3/order"

    order_params =
      params
      |> Map.take([:symbol, :side, :type, :quantity, :price, :time_in_force,
                    :stop_price, :reduce_only, :position_side, :new_client_order_id,
                    :newOrderRespType, :recvWindow])
      |> Enum.map(fn {k, v} -> {to_binance_key(k), to_string(v)} end)

    signed_post(market, path, order_params, opts)
  end

  @doc """
  Cancels an order by symbol and order ID.

  ## Parameters

    * `market` — `:spot` or `:futures`
    * `symbol` — Trading pair symbol
    * `order_id` — Order ID to cancel
    * `opts` — Optional request options
  """
  @spec cancel_order(market_type(), String.t(), integer(), request_opts()) :: {:ok, term()} | {:error, term()}
  def cancel_order(market, symbol, order_id, opts \\ %{}) do
    opts = normalize_opts(opts)
    path = if market == :futures, do: "/fapi/v1/order", else: "/api/v3/order"

    with :ok <- check_rate_limit(opts[:rate_limiter], market),
         {:ok, result} <- signed_delete(market, path, [symbol: symbol, orderId: order_id], opts) do
      {:ok, result}
    end
  end

  @doc """
  Cancels all open orders for a symbol.

  ## Parameters

    * `market` — `:spot` or `:futures`
    * `symbol` — Trading pair symbol
    * `opts` — Optional request options
  """
  @spec cancel_all_orders(market_type(), String.t(), request_opts()) :: {:ok, term()} | {:error, term()}
  def cancel_all_orders(market, symbol, opts \\ %{}) do
    opts = normalize_opts(opts)
    path = if market == :futures, do: "/fapi/v1/allOpenOrders", else: "/api/v3/openOrders"

    with :ok <- check_rate_limit(opts[:rate_limiter], market),
         {:ok, result} <- signed_delete(market, path, [symbol: symbol], opts) do
      {:ok, result}
    end
  end

  @doc """
  Gets the status of an order.

  ## Parameters

    * `market` — `:spot` or `:futures`
    * `symbol` — Trading pair symbol
    * `order_id` — Order ID to query
    * `opts` — Optional request options
  """
  @spec get_order(market_type(), String.t(), integer(), request_opts()) :: {:ok, term()} | {:error, term()}
  def get_order(market, symbol, order_id, opts \\ %{}) do
    opts = normalize_opts(opts)
    path = if market == :futures, do: "/fapi/v1/order", else: "/api/v3/order"

    with :ok <- check_rate_limit(opts[:rate_limiter], market),
         {:ok, result} <- signed_get(market, path, [symbol: symbol, orderId: order_id], opts) do
      {:ok, result}
    end
  end

  @doc """
  Gets all open orders for a symbol, or all symbols.

  ## Parameters

    * `market` — `:spot` or `:futures`
    * `symbol` — Trading pair symbol (optional)
    * `opts` — Optional request options
  """
  @spec get_open_orders(market_type(), String.t() | nil, request_opts()) :: {:ok, term()} | {:error, term()}
  def get_open_orders(market, symbol \\ nil, opts \\ %{}) do
    opts = normalize_opts(opts)
    path = if market == :futures, do: "/fapi/v1/openOrders", else: "/api/v3/openOrders"
    params = if symbol, do: [symbol: symbol], else: []

    with :ok <- check_rate_limit(opts[:rate_limiter], market),
         {:ok, result} <- signed_get(market, path, params, opts) do
      {:ok, result}
    end
  end

  @doc """
  Gets account information including balances.

  ## Parameters

    * `market` — `:spot` or `:futures`
    * `opts` — Optional request options
  """
  @spec get_account_info(market_type(), request_opts()) :: {:ok, term()} | {:error, term()}
  def get_account_info(market, opts \\ %{}) do
    opts = normalize_opts(opts)
    path = if market == :futures, do: "/fapi/v2/account", else: "/api/v3/account"

    with :ok <- check_rate_limit(opts[:rate_limiter], market),
         {:ok, result} <- signed_get(market, path, [], opts) do
      {:ok, result}
    end
  end

  @doc """
  Gets position information (futures only).

  ## Parameters

    * `symbol` — Trading pair symbol (optional)
    * `opts` — Optional request options
  """
  @spec get_position_info(String.t() | nil, request_opts()) :: {:ok, term()} | {:error, term()}
  def get_position_info(symbol \\ nil, opts \\ %{}) do
    opts = normalize_opts(opts)
    params = if symbol, do: [symbol: symbol], else: []

    with :ok <- check_rate_limit(opts[:rate_limiter], :futures),
         {:ok, result} <- signed_get(:futures, "/fapi/v2/positionRisk", params, opts) do
      {:ok, result}
    end
  end

  @doc """
  Gets funding rate history (futures only).

  ## Parameters

    * `symbol` — Trading pair symbol (optional)
    * `start_time` — Start time in milliseconds (optional)
    * `end_time` — End time in milliseconds (optional)
    * `limit` — Number of results (default: 100, max: 1000)
    * `opts` — Optional request options
  """
  @spec get_funding_rate(String.t() | nil, integer() | nil, integer() | nil, integer(), request_opts()) ::
          {:ok, term()} | {:error, term()}
  def get_funding_rate(symbol \\ nil, start_time \\ nil, end_time \\ nil, limit \\ 100, opts \\ %{}) do
    params =
      []
      |> maybe_add_param(:symbol, symbol)
      |> maybe_add_param(:startTime, start_time)
      |> maybe_add_param(:endTime, end_time)
      |> Keyword.put(:limit, limit)

    get(:futures, "/fapi/v1/fundingRate", params, opts)
  end

  @doc """
  Gets futures account balance.

  ## Parameters

    * `opts` — Optional request options
  """
  @spec get_futures_balance(request_opts()) :: {:ok, term()} | {:error, term()}
  def get_futures_balance(opts \\ %{}) do
    opts = normalize_opts(opts)

    with :ok <- check_rate_limit(opts[:rate_limiter], :futures),
         {:ok, result} <- signed_get(:futures, "/fapi/v2/balance", [], opts) do
      {:ok, result}
    end
  end

  @doc """
  Changes leverage for a symbol (futures only).

  ## Parameters

    * `symbol` — Trading pair symbol
    * `leverage` — Target leverage (1-125)
    * `opts` — Optional request options
  """
  @spec change_leverage(String.t(), integer(), request_opts()) :: {:ok, term()} | {:error, term()}
  def change_leverage(symbol, leverage, opts \\ %{}) do
    opts = normalize_opts(opts)

    with :ok <- check_rate_limit(opts[:rate_limiter], :futures),
         {:ok, result} <- signed_post(:futures, "/fapi/v1/leverage",
                           [symbol: symbol, leverage: leverage], opts) do
      {:ok, result}
    end
  end

  @doc """
  Changes margin type for a symbol (futures only).

  ## Parameters

    * `symbol` — Trading pair symbol
    * `margin_type` — "ISOLATED" or "CROSSED"
    * `opts` — Optional request options
  """
  @spec change_margin_type(String.t(), String.t(), request_opts()) :: {:ok, term()} | {:error, term()}
  def change_margin_type(symbol, margin_type, opts \\ %{}) do
    opts = normalize_opts(opts)

    with :ok <- check_rate_limit(opts[:rate_limiter], :futures),
         {:ok, result} <- signed_post(:futures, "/fapi/v1/marginType",
                           [symbol: symbol, marginType: margin_type], opts) do
      {:ok, result}
    end
  end

  @doc """
  Creates a listen key for user data stream.

  ## Parameters

    * `market` — `:spot` or `:futures`
    * `opts` — Optional request options
  """
  @spec create_listen_key(market_type(), request_opts()) :: {:ok, term()} | {:error, term()}
  def create_listen_key(market, opts \\ %{}) do
    opts = normalize_opts(opts)
    path = if market == :futures, do: "/fapi/v1/listenKey", else: "/api/v3/userDataStream"

    with :ok <- check_rate_limit(opts[:rate_limiter], market),
         {:ok, result} <- signed_post(market, path, [], opts) do
      {:ok, result}
    end
  end

  @doc """
  Keeps a listen key alive (ping every 30 minutes).

  ## Parameters

    * `market` — `:spot` or `:futures`
    * `listen_key` — The listen key to extend
    * `opts` — Optional request options
  """
  @spec keep_alive_listen_key(market_type(), String.t(), request_opts()) :: {:ok, term()} | {:error, term()}
  def keep_alive_listen_key(market, listen_key, opts \\ %{}) do
    opts = normalize_opts(opts)
    path = if market == :futures, do: "/fapi/v1/listenKey", else: "/api/v3/userDataStream"

    put(market, path, [listenKey: listen_key], opts)
  end

  defp get(market, path, params, opts) do
    request(:get, market, path, params, opts)
  end

  defp signed_get(market, path, params, opts) do
    signed_request(:get, market, path, params, opts)
  end

  defp signed_post(market, path, params, opts) do
    signed_request(:post, market, path, params, opts)
  end

  defp signed_delete(market, path, params, opts) do
    signed_request(:delete, market, path, params, opts)
  end

  defp put(market, path, params, opts) do
    request(:put, market, path, params, opts)
  end

  defp request(method, market, path, params, opts) do
    opts = normalize_opts(opts)
    base_url = Keyword.get(opts, :base_url, base_url(market))
    url = build_url(base_url, path, params)

    [
      method: method,
      url: url,
      headers: build_headers()
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(opts[:plug])
    |> Req.new()
    |> Req.request()
    |> handle_response()
  end

  defp signed_request(method, market, path, params, opts) do
    opts = normalize_opts(opts)
    base_url = Keyword.get(opts, :base_url, base_url(market))

    with {:ok, api_key} <- get_api_key(),
         {:ok, secret_key} <- get_secret_key() do
      timestamp = System.system_time(:millisecond)
      recv_window = Keyword.get(params, :recvWindow, 5000) |> to_string() |> String.to_integer()

      query_params =
        params
        |> Keyword.put(:timestamp, timestamp)
        |> Keyword.put(:recvWindow, recv_window)

      query_string = encode_query(query_params)
      signature = hmac_sha256(secret_key, query_string)
      signed_query = query_string <> "&signature=" <> signature

      url = base_url <> path <> "?" <> signed_query

      [
        method: method,
        url: url,
        headers: [{"X-MBX-APIKEY", api_key} | build_headers()]
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
      |> maybe_add_plug(opts[:plug])
      |> Req.new()
      |> Req.request()
      |> handle_response()
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_headers do
    [{"Content-Type", "application/x-www-form-urlencoded"}]
  end

  defp build_url(base_url, path, []) do
    base_url <> path
  end

  defp build_url(base_url, path, params) do
    base_url <> path <> "?" <> encode_query(params)
  end

  defp encode_query(params) do
    params
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.map(fn {k, v} -> "#{k}=#{URI.encode_www_form(to_string(v))}" end)
    |> Enum.join("&")
  end

  defp hmac_sha256(key, data) do
    :crypto.mac(:hmac, :sha256, key, data)
    |> Base.encode16(case: :lower)
  end

  @doc """
  TestNet / sandbox base URLs for paper-trading and CI safety.

  Set the env var `BINANCE_TESTNET=true` to route all signed
  requests to the Binance Spot Test Network and Futures Testnet.

  When testnet mode is disabled, `place_order` and other signed
  endpoints will refuse to operate unless explicitly permitted
  via `BINANCE_ALLOW_LIVE_TRADING=true`.
  """
  @spot_testnet_url "https://testnet.binance.vision"
  @futures_testnet_url "https://testnet.binancefuture.com"

  defp base_url(:spot), do: testnet_url(@spot_base_url, @spot_testnet_url)
  defp base_url(:futures), do: testnet_url(@futures_base_url, @futures_testnet_url)

  defp testnet_url(prod_url, testnet_url) do
    case System.get_env("BINANCE_TESTNET") do
      "true" -> testnet_url
      _ -> prod_url
    end
  end

  defp sandbox_guard do
    testnet? = System.get_env("BINANCE_TESTNET") == "true"
    allow_live? = System.get_env("BINANCE_ALLOW_LIVE_TRADING") == "true"
    test_env? = Mix.env() == :test

    cond do
      test_env? -> :ok
      testnet? -> :ok
      allow_live? -> :ok
      true -> {:error, :live_trading_blocked}
    end
  end

  defp get_api_key do
    {:ok, Config.binance_api_key()}
  rescue
    RuntimeError -> {:error, :missing_api_key}
  end

  defp get_secret_key do
    {:ok, Config.binance_secret_key()}
  rescue
    RuntimeError -> {:error, :missing_secret_key}
  end

  defp check_rate_limit(nil, _market), do: :ok

  defp check_rate_limit(rate_limiter, market) do
    bucket = if market == :futures, do: :futures, else: :spot
    RateLimiter.acquire(rate_limiter, bucket)
  end

  defp maybe_add_param(params, _key, nil), do: params
  defp maybe_add_param(params, key, value), do: Keyword.put(params, key, value)

  defp normalize_opts(opts) when is_map(opts), do: Enum.to_list(opts)
  defp normalize_opts(opts), do: opts

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)

  defp to_binance_key(:time_in_force), do: :timeInForce
  defp to_binance_key(:stop_price), do: :stopPrice
  defp to_binance_key(:reduce_only), do: :reduceOnly
  defp to_binance_key(:position_side), do: :positionSide
  defp to_binance_key(:new_client_order_id), do: :newClientOrderId
  defp to_binance_key(:newOrderRespType), do: :newOrderRespType
  defp to_binance_key(:recvWindow), do: :recvWindow
  defp to_binance_key(k) when is_atom(k), do: k
  defp to_binance_key(k) when is_binary(k), do: String.to_existing_atom(k)

  defp handle_response({:ok, %{status: status} = response}) when status in 200..299 do
    {:ok, response.body}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    Logger.error("Binance API error: status=#{status}, body=#{inspect(body)}")
    {:error, {status, body}}
  end

  defp handle_response({:error, error}) do
    Logger.error("Binance API request failed: #{inspect(error)}")
    {:error, error}
  end
end
