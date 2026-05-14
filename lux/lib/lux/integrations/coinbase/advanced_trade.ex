defmodule Lux.Integrations.Coinbase.AdvancedTrade do
  @moduledoc """
  Coinbase Advanced Trade operation planning and normalization.

  This module builds deterministic REST/WebSocket request plans, order payloads,
  account snapshots, market-data summaries, and rate-limit budgets without
  holding secrets or submitting live orders.
  """

  @api_host "api.coinbase.com"
  @rest_prefix "/api/v3/brokerage"
  @public_actions [
    :list_products,
    :get_product,
    :product_book,
    :market_trades,
    :candles,
    :best_bid_ask
  ]
  @private_actions [
    :accounts,
    :account,
    :portfolios,
    :orders,
    :create_order,
    :cancel_order,
    :fills
  ]
  @channels ["ticker", "ticker_batch", "level2", "market_trades", "status", "heartbeats", "user"]

  @doc "Builds all core Coinbase operation plans for a product."
  @spec plan(map()) :: map()
  def plan(attrs \\ %{}) when is_map(attrs) do
    attrs = normalize_keys(attrs)
    product_id = Map.get(attrs, :product_id, "BTC-USD")
    channels = list(attrs, :channels, ["ticker", "level2", "market_trades", "heartbeats"])

    %{
      rest_api: rest_plans(attrs),
      websocket:
        websocket_subscription(channels, [product_id], Map.get(attrs, :authenticated?, false)),
      order_management: %{
        create_order: order_payload(attrs),
        cancel_order: request_plan(:cancel_order, attrs),
        open_orders: request_plan(:orders, attrs)
      },
      market_data: market_snapshot(Map.get(attrs, :market_data, %{})),
      portfolio: portfolio_snapshot(Map.get(attrs, :accounts, []), Map.get(attrs, :prices, %{})),
      rate_limits: rate_limit_budget(Map.get(attrs, :request_history, []), attrs),
      coverage: [
        :rest_api_integration,
        :websocket_feeds,
        :order_management,
        :market_data_streaming,
        :portfolio_tracking,
        :account_management,
        :historical_data_access,
        :rate_limit_handling
      ],
      safety: %{
        mode: :plan_only,
        submits_live_orders: false,
        stores_api_secrets: false,
        requires_transport_signing: true
      }
    }
  end

  @doc "Builds REST request plans for public and private Advanced Trade endpoints."
  @spec rest_plans(map()) :: [map()]
  def rest_plans(attrs \\ %{}) when is_map(attrs) do
    attrs = normalize_keys(attrs)

    [
      request_plan(:list_products, attrs),
      request_plan(:get_product, attrs),
      request_plan(:product_book, attrs),
      request_plan(:market_trades, attrs),
      request_plan(:candles, attrs),
      request_plan(:best_bid_ask, attrs),
      request_plan(:accounts, attrs),
      request_plan(:account, attrs),
      request_plan(:portfolios, attrs),
      request_plan(:orders, attrs),
      request_plan(:create_order, attrs),
      request_plan(:cancel_order, attrs),
      request_plan(:fills, attrs)
    ]
  end

  @doc "Builds a single REST request plan."
  @spec request_plan(atom(), map()) :: map()
  def request_plan(action, attrs \\ %{}) when is_atom(action) and is_map(attrs) do
    attrs = normalize_keys(attrs)
    product_id = Map.get(attrs, :product_id, "BTC-USD")
    account_id = Map.get(attrs, :account_id, "ACCOUNT_ID")
    order_id = Map.get(attrs, :order_id, "ORDER_ID")
    portfolio_id = Map.get(attrs, :portfolio_id, "PORTFOLIO_ID")

    {method, path, query, body} =
      case action do
        :list_products ->
          {:get, "#{@rest_prefix}/products", %{limit: Map.get(attrs, :limit, 100)}, %{}}

        :get_product ->
          {:get, "#{@rest_prefix}/products/#{product_id}", %{}, %{}}

        :product_book ->
          {:get, "#{@rest_prefix}/product_book",
           %{product_id: product_id, limit: Map.get(attrs, :limit, 50)}, %{}}

        :market_trades ->
          {:get, "#{@rest_prefix}/products/#{product_id}/ticker",
           %{limit: Map.get(attrs, :limit, 100)}, %{}}

        :candles ->
          {:get, "#{@rest_prefix}/products/#{product_id}/candles", candle_query(attrs), %{}}

        :best_bid_ask ->
          {:get, "#{@rest_prefix}/best_bid_ask", %{product_ids: product_id}, %{}}

        :accounts ->
          {:get, "#{@rest_prefix}/accounts", %{limit: Map.get(attrs, :limit, 100)}, %{}}

        :account ->
          {:get, "#{@rest_prefix}/accounts/#{account_id}", %{}, %{}}

        :portfolios ->
          {:get, "#{@rest_prefix}/portfolios", %{}, %{}}

        :orders ->
          {:get, "#{@rest_prefix}/orders/historical/batch", orders_query(attrs, portfolio_id),
           %{}}

        :create_order ->
          {:post, "#{@rest_prefix}/orders", %{}, order_payload(attrs)}

        :cancel_order ->
          {:post, "#{@rest_prefix}/orders/batch_cancel", %{}, %{order_ids: [order_id]}}

        :fills ->
          {:get, "#{@rest_prefix}/orders/historical/fills", orders_query(attrs, portfolio_id),
           %{}}
      end

    %{
      action: action,
      method: method,
      host: @api_host,
      path: path,
      query: query,
      body: body,
      auth_required: action in @private_actions,
      idempotency_key: idempotency_key(action, body),
      rate_limit_key: rate_limit_key(action),
      jwt_claims: jwt_claim_plan(method, path, action in @private_actions)
    }
  end

  @doc "Builds a Coinbase Advanced Trade order payload."
  @spec order_payload(map()) :: map()
  def order_payload(attrs \\ %{}) when is_map(attrs) do
    attrs = normalize_keys(attrs)
    side = attrs |> Map.get(:side, "BUY") |> normalize_side()
    type = attrs |> Map.get(:order_type, "limit") |> normalize_order_type()
    product_id = Map.get(attrs, :product_id, "BTC-USD")
    client_order_id = Map.get(attrs, :client_order_id, deterministic_client_order_id(attrs))

    %{
      client_order_id: client_order_id,
      product_id: product_id,
      side: side,
      order_configuration: order_configuration(type, attrs)
    }
  end

  @doc "Builds a WebSocket subscription payload."
  @spec websocket_subscription([String.t()] | String.t(), [String.t()] | String.t(), boolean()) ::
          map()
  def websocket_subscription(channels, product_ids, authenticated? \\ false) do
    normalized_channels =
      channels
      |> List.wrap()
      |> Enum.map(&to_string/1)
      |> Enum.map(&String.downcase/1)
      |> Enum.filter(&(&1 in @channels))
      |> Enum.uniq()

    %{
      type: "subscribe",
      product_ids: product_ids |> List.wrap() |> Enum.map(&to_string/1) |> Enum.uniq(),
      channels: normalized_channels,
      auth_required: authenticated? or "user" in normalized_channels,
      sequence_tracking: true,
      heartbeat_required: "heartbeats" in normalized_channels
    }
  end

  @doc "Normalizes account balances and computes portfolio value from supplied prices."
  @spec portfolio_snapshot([map()], map()) :: map()
  def portfolio_snapshot(accounts, prices \\ %{}) when is_list(accounts) and is_map(prices) do
    prices = normalize_price_map(prices)

    positions =
      accounts
      |> Enum.map(&normalize_account/1)
      |> Enum.map(fn account ->
        price =
          Map.get(prices, account.currency, if(account.currency == "USD", do: 1.0, else: nil))

        value = if price, do: round_float(account.available * price), else: nil

        Map.merge(account, %{
          reference_price_usd: price,
          value_usd: value
        })
      end)

    %{
      positions: positions,
      total_value_usd: positions |> Enum.map(& &1.value_usd) |> Enum.filter(&number?/1) |> sum(),
      currencies: Enum.map(positions, & &1.currency),
      account_count: length(positions)
    }
  end

  @doc "Builds a compact market-data snapshot from product, book, ticker, trade, and candle data."
  @spec market_snapshot(map()) :: map()
  def market_snapshot(attrs \\ %{}) when is_map(attrs) do
    attrs = normalize_keys(attrs)
    book = normalize_book(Map.get(attrs, :book, %{}))
    trades = normalize_trades(Map.get(attrs, :trades, []))
    candles = normalize_candles(Map.get(attrs, :candles, []))

    %{
      product: normalize_product(Map.get(attrs, :product, %{})),
      ticker: normalize_ticker(Map.get(attrs, :ticker, %{})),
      order_book: book,
      recent_trades: trades,
      candles: candles,
      best_bid: best_level(book.bids),
      best_ask: best_level(book.asks),
      mid_price: mid_price(book),
      trade_volume: trades |> Enum.map(& &1.size) |> Enum.filter(&number?/1) |> sum(),
      candle_count: length(candles)
    }
  end

  @doc "Summarizes REST/WebSocket request usage against a rate-limit window."
  @spec rate_limit_budget([map()], map()) :: map()
  def rate_limit_budget(history, attrs \\ %{}) when is_list(history) and is_map(attrs) do
    attrs = normalize_keys(attrs)
    limit = integer(Map.get(attrs, :rate_limit, 30))
    window_seconds = integer(Map.get(attrs, :rate_limit_window_seconds, 1))
    cost_by_action = Map.get(attrs, :rate_limit_costs, %{})

    used =
      history
      |> Enum.map(fn event ->
        event = normalize_keys(event)
        action = Map.get(event, :action, :request)
        Map.get(cost_by_action, action, 1)
      end)
      |> Enum.sum()

    %{
      limit: limit,
      window_seconds: window_seconds,
      used: used,
      remaining: max(limit - used, 0),
      throttled?: used >= limit,
      retry_after_ms: if(used >= limit, do: window_seconds * 1000, else: 0)
    }
  end

  defp candle_query(attrs) do
    %{
      start: Map.get(attrs, :start, "START_UNIX_SECONDS"),
      end: Map.get(attrs, :end, "END_UNIX_SECONDS"),
      granularity: Map.get(attrs, :granularity, "ONE_HOUR")
    }
  end

  defp orders_query(attrs, portfolio_id) do
    %{
      product_id: Map.get(attrs, :product_id, "BTC-USD"),
      order_status: Map.get(attrs, :order_status, "OPEN"),
      limit: Map.get(attrs, :limit, 100),
      portfolio_id: portfolio_id
    }
  end

  defp order_configuration("market", attrs) do
    if present?(Map.get(attrs, :quote_size)) do
      %{market_market_ioc: %{quote_size: amount(attrs, :quote_size)}}
    else
      %{market_market_ioc: %{base_size: amount(attrs, :base_size)}}
    end
  end

  defp order_configuration("limit", attrs) do
    %{
      limit_limit_gtc: %{
        base_size: amount(attrs, :base_size),
        limit_price: amount(attrs, :limit_price),
        post_only: Map.get(attrs, :post_only, false)
      }
    }
  end

  defp order_configuration("stop_limit", attrs) do
    %{
      stop_limit_stop_limit_gtc: %{
        base_size: amount(attrs, :base_size),
        limit_price: amount(attrs, :limit_price),
        stop_price: amount(attrs, :stop_price),
        stop_direction: attrs |> Map.get(:stop_direction, "STOP_DIRECTION_STOP_UP") |> to_string()
      }
    }
  end

  defp order_configuration(_type, attrs), do: order_configuration("limit", attrs)

  defp normalize_side(side) do
    case side |> to_string() |> String.upcase() do
      "SELL" -> "SELL"
      _ -> "BUY"
    end
  end

  defp normalize_order_type(type) do
    type
    |> to_string()
    |> String.downcase()
    |> String.replace("-", "_")
  end

  defp deterministic_client_order_id(attrs) do
    product_id = Map.get(attrs, :product_id, "BTC-USD")
    side = attrs |> Map.get(:side, "BUY") |> normalize_side()
    type = attrs |> Map.get(:order_type, "limit") |> normalize_order_type()
    "lux-coinbase-#{String.downcase(product_id)}-#{String.downcase(side)}-#{type}"
  end

  defp amount(attrs, key) do
    attrs
    |> Map.get(key, "0")
    |> to_string()
  end

  defp idempotency_key(:create_order, body), do: Map.get(body, :client_order_id)
  defp idempotency_key(_action, _body), do: nil

  defp rate_limit_key(action) when action in @public_actions, do: "coinbase:public"
  defp rate_limit_key(action) when action in @private_actions, do: "coinbase:private"
  defp rate_limit_key(_action), do: "coinbase:generic"

  defp jwt_claim_plan(method, path, true) do
    %{
      algorithm: "ES256",
      uri: "#{String.upcase(to_string(method))} #{@api_host}#{path}",
      claims: [:iss, :nbf, :exp, :sub, :uri],
      ttl_seconds: 120,
      signing_required_in_transport: true
    }
  end

  defp jwt_claim_plan(_method, _path, false), do: nil

  defp normalize_account(account) do
    account = normalize_keys(account)
    balance = normalize_keys(Map.get(account, :available_balance, %{}))
    hold = normalize_keys(Map.get(account, :hold, %{}))

    %{
      uuid: Map.get(account, :uuid, ""),
      currency: account |> Map.get(:currency, Map.get(balance, :currency, "USD")) |> to_string(),
      available: money(Map.get(balance, :value, Map.get(account, :available, 0))),
      hold: money(Map.get(hold, :value, Map.get(account, :hold_amount, 0))),
      trading_enabled: Map.get(account, :trading_enabled, true)
    }
  end

  defp normalize_price_map(prices) do
    Map.new(prices, fn {currency, price} ->
      {currency |> to_string() |> String.upcase(), money(price)}
    end)
  end

  defp normalize_product(product) do
    product = normalize_keys(product || %{})

    %{
      product_id: Map.get(product, :product_id, Map.get(product, :productId, "")),
      base_currency: Map.get(product, :base_currency, Map.get(product, :baseCurrencyId, "")),
      quote_currency: Map.get(product, :quote_currency, Map.get(product, :quoteCurrencyId, "")),
      price_increment: Map.get(product, :price_increment, nil),
      base_increment: Map.get(product, :base_increment, nil)
    }
  end

  defp normalize_ticker(ticker) do
    ticker = normalize_keys(ticker || %{})

    %{
      product_id: Map.get(ticker, :product_id, Map.get(ticker, :productId, "")),
      price: money(Map.get(ticker, :price, Map.get(ticker, :best_bid, nil))),
      best_bid: money(Map.get(ticker, :best_bid, nil)),
      best_ask: money(Map.get(ticker, :best_ask, nil)),
      volume_24h: money(Map.get(ticker, :volume_24h, nil))
    }
  end

  defp normalize_book(book) do
    book = normalize_keys(book || %{})

    %{
      bids: normalize_levels(Map.get(book, :bids, []), :desc),
      asks: normalize_levels(Map.get(book, :asks, []), :asc),
      sequence: Map.get(book, :sequence, nil)
    }
  end

  defp normalize_levels(levels, direction) when is_list(levels) do
    levels
    |> Enum.map(fn level ->
      level = normalize_keys(level)

      %{
        price: money(level_value(level, :price, 0)),
        size: money(level_value(level, :size, 1))
      }
    end)
    |> Enum.filter(&number?(&1.price))
    |> Enum.sort_by(& &1.price, direction)
  end

  defp normalize_levels(_levels, _direction), do: []

  defp level_value(level, key, _index) when is_map(level), do: Map.get(level, key)
  defp level_value(level, _key, index) when is_list(level), do: Enum.at(level, index)
  defp level_value(_level, _key, _index), do: nil

  defp normalize_trades(trades) when is_list(trades) do
    Enum.map(trades, fn trade ->
      trade = normalize_keys(trade)

      %{
        trade_id: Map.get(trade, :trade_id, Map.get(trade, :tradeId, "")),
        product_id: Map.get(trade, :product_id, Map.get(trade, :productId, "")),
        price: money(Map.get(trade, :price, 0)),
        size: money(Map.get(trade, :size, 0)),
        side: trade |> Map.get(:side, "") |> to_string() |> String.upcase(),
        time: Map.get(trade, :time, Map.get(trade, :timestamp, nil))
      }
    end)
  end

  defp normalize_trades(_trades), do: []

  defp normalize_candles(candles) when is_list(candles) do
    Enum.map(candles, fn candle ->
      candle = normalize_keys(candle)

      %{
        start: Map.get(candle, :start, nil),
        low: money(Map.get(candle, :low, nil)),
        high: money(Map.get(candle, :high, nil)),
        open: money(Map.get(candle, :open, nil)),
        close: money(Map.get(candle, :close, nil)),
        volume: money(Map.get(candle, :volume, nil))
      }
    end)
  end

  defp normalize_candles(_candles), do: []

  defp best_level([]), do: nil
  defp best_level([level | _]), do: level

  defp mid_price(%{bids: [%{price: bid} | _], asks: [%{price: ask} | _]}) do
    round_float((bid + ask) / 2)
  end

  defp mid_price(_book), do: nil

  defp present?(value), do: value not in [nil, ""]

  defp list(attrs, key, default) do
    case Map.get(attrs, key, default) do
      value when is_list(value) -> Enum.map(value, &to_string/1)
      value when is_binary(value) -> [value]
      _ -> default
    end
  end

  defp normalize_keys(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {key, value} when is_binary(key) -> {known_key(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp normalize_keys(value), do: value

  defp known_key("authenticated?"), do: :authenticated?
  defp known_key("product_id"), do: :product_id
  defp known_key("productId"), do: :productId
  defp known_key("account_id"), do: :account_id
  defp known_key("portfolio_id"), do: :portfolio_id
  defp known_key("order_id"), do: :order_id
  defp known_key("order_status"), do: :order_status
  defp known_key("order_type"), do: :order_type
  defp known_key("client_order_id"), do: :client_order_id
  defp known_key("side"), do: :side
  defp known_key("base_size"), do: :base_size
  defp known_key("quote_size"), do: :quote_size
  defp known_key("limit_price"), do: :limit_price
  defp known_key("stop_price"), do: :stop_price
  defp known_key("stop_direction"), do: :stop_direction
  defp known_key("post_only"), do: :post_only
  defp known_key("channels"), do: :channels
  defp known_key("limit"), do: :limit
  defp known_key("start"), do: :start
  defp known_key("end"), do: :end
  defp known_key("granularity"), do: :granularity
  defp known_key("market_data"), do: :market_data
  defp known_key("accounts"), do: :accounts
  defp known_key("prices"), do: :prices
  defp known_key("request_history"), do: :request_history
  defp known_key("rate_limit"), do: :rate_limit
  defp known_key("rate_limit_window_seconds"), do: :rate_limit_window_seconds
  defp known_key("rate_limit_costs"), do: :rate_limit_costs
  defp known_key("action"), do: :action
  defp known_key("available_balance"), do: :available_balance
  defp known_key("available"), do: :available
  defp known_key("hold"), do: :hold
  defp known_key("hold_amount"), do: :hold_amount
  defp known_key("value"), do: :value
  defp known_key("currency"), do: :currency
  defp known_key("uuid"), do: :uuid
  defp known_key("trading_enabled"), do: :trading_enabled
  defp known_key("product"), do: :product
  defp known_key("ticker"), do: :ticker
  defp known_key("book"), do: :book
  defp known_key("bids"), do: :bids
  defp known_key("asks"), do: :asks
  defp known_key("sequence"), do: :sequence
  defp known_key("trades"), do: :trades
  defp known_key("trade_id"), do: :trade_id
  defp known_key("tradeId"), do: :tradeId
  defp known_key("candles"), do: :candles
  defp known_key("price"), do: :price
  defp known_key("size"), do: :size
  defp known_key("time"), do: :time
  defp known_key("timestamp"), do: :timestamp
  defp known_key("base_currency"), do: :base_currency
  defp known_key("baseCurrencyId"), do: :baseCurrencyId
  defp known_key("quote_currency"), do: :quote_currency
  defp known_key("quoteCurrencyId"), do: :quoteCurrencyId
  defp known_key("price_increment"), do: :price_increment
  defp known_key("base_increment"), do: :base_increment
  defp known_key("best_bid"), do: :best_bid
  defp known_key("best_ask"), do: :best_ask
  defp known_key("volume_24h"), do: :volume_24h
  defp known_key("low"), do: :low
  defp known_key("high"), do: :high
  defp known_key("open"), do: :open
  defp known_key("close"), do: :close
  defp known_key("volume"), do: :volume
  defp known_key(key), do: key

  defp money(nil), do: nil
  defp money(value) when is_integer(value), do: value * 1.0
  defp money(value) when is_float(value), do: value

  defp money(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _rest} -> number
      :error -> nil
    end
  end

  defp money(_), do: nil

  defp integer(value) when is_integer(value), do: value
  defp integer(value) when is_float(value), do: round(value)

  defp integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, _rest} -> number
      :error -> 0
    end
  end

  defp integer(_), do: 0

  defp number?(value), do: is_integer(value) or is_float(value)
  defp round_float(value), do: Float.round(value * 1.0, 8)
  defp sum(values), do: values |> Enum.sum() |> round_float()
end
