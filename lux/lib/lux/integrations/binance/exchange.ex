defmodule Lux.Integrations.Binance.Exchange do
  @moduledoc """
  Transport-neutral Binance exchange integration helpers.

  The module builds deterministic request, order, stream, portfolio, and rate-limit plans. It
  deliberately does not store API keys, compute signatures, open sockets, or submit live orders.
  """

  @spot_base_url "https://api.binance.com"
  @futures_base_url "https://fapi.binance.com"
  @spot_ws_url "wss://stream.binance.com:9443"
  @futures_ws_url "wss://fstream.binance.com"
  @default_recv_window 5_000

  @endpoints %{
    spot: %{
      exchange_info: %{method: :get, path: "/api/v3/exchangeInfo", weight: 20, signed: false},
      ticker_price: %{method: :get, path: "/api/v3/ticker/price", weight: 1, signed: false},
      ticker_24hr: %{method: :get, path: "/api/v3/ticker/24hr", weight: 1, signed: false},
      order_book: %{method: :get, path: "/api/v3/depth", weight: 5, signed: false},
      klines: %{method: :get, path: "/api/v3/klines", weight: 2, signed: false},
      account: %{method: :get, path: "/api/v3/account", weight: 10, signed: true},
      open_orders: %{method: :get, path: "/api/v3/openOrders", weight: 6, signed: true},
      new_order: %{method: :post, path: "/api/v3/order", weight: 1, signed: true},
      cancel_order: %{method: :delete, path: "/api/v3/order", weight: 1, signed: true},
      query_order: %{method: :get, path: "/api/v3/order", weight: 2, signed: true}
    },
    futures: %{
      exchange_info: %{method: :get, path: "/fapi/v1/exchangeInfo", weight: 1, signed: false},
      ticker_price: %{method: :get, path: "/fapi/v1/ticker/price", weight: 1, signed: false},
      ticker_24hr: %{method: :get, path: "/fapi/v1/ticker/24hr", weight: 1, signed: false},
      order_book: %{method: :get, path: "/fapi/v1/depth", weight: 5, signed: false},
      klines: %{method: :get, path: "/fapi/v1/klines", weight: 1, signed: false},
      account: %{method: :get, path: "/fapi/v2/account", weight: 5, signed: true},
      position_risk: %{method: :get, path: "/fapi/v2/positionRisk", weight: 5, signed: true},
      open_orders: %{method: :get, path: "/fapi/v1/openOrders", weight: 1, signed: true},
      new_order: %{method: :post, path: "/fapi/v1/order", weight: 1, signed: true},
      cancel_order: %{method: :delete, path: "/fapi/v1/order", weight: 1, signed: true},
      query_order: %{method: :get, path: "/fapi/v1/order", weight: 1, signed: true}
    }
  }

  @stream_aliases %{
    ticker: "ticker",
    trade: "trade",
    agg_trade: "aggTrade",
    depth: "depth20@100ms",
    book_ticker: "bookTicker",
    kline_1m: "kline_1m",
    mark_price: "markPrice"
  }

  @doc "Builds a Binance REST request plan for public or signed endpoints."
  def rest_request_plan(attrs) when is_map(attrs) do
    market = attrs |> value(:market, :spot) |> normalize_market()
    endpoint = attrs |> value(:endpoint) |> normalize_endpoint()

    with {:ok, endpoint_spec} <- endpoint_spec(market, endpoint) do
      params =
        attrs
        |> value(:params, %{})
        |> normalize_params()
        |> maybe_put_symbol(attrs)
        |> maybe_put_default_limit(endpoint)
        |> maybe_put_signed_fields(endpoint_spec, attrs)

      query = query_string(params)
      base_url = base_url(market)
      url = request_url(base_url, endpoint_spec.path, query)

      {:ok,
       %{
         market: market,
         endpoint: endpoint,
         method: endpoint_spec.method,
         url: url,
         path: endpoint_spec.path,
         signed: endpoint_spec.signed,
         weight: endpoint_spec.weight,
         params: params,
         signature_payload: if(endpoint_spec.signed, do: query, else: nil),
         headers: request_headers(endpoint_spec.signed)
       }}
    end
  end

  @doc "Normalizes a spot order and returns the matching signed REST request plan."
  def spot_order_plan(attrs) when is_map(attrs) do
    with {:ok, order} <- normalize_order(attrs, :spot),
         {:ok, request} <-
           rest_request_plan(%{
             market: :spot,
             endpoint: :new_order,
             params: order,
             timestamp: value(attrs, :timestamp),
             recv_window: value(attrs, :recv_window, @default_recv_window)
           }) do
      {:ok, %{market: :spot, order: order, request: request, validation: order_validation(order)}}
    end
  end

  @doc "Normalizes a USD-M futures order and returns the matching signed REST request plan."
  def futures_order_plan(attrs) when is_map(attrs) do
    with {:ok, order} <- normalize_order(attrs, :futures),
         {:ok, request} <-
           rest_request_plan(%{
             market: :futures,
             endpoint: :new_order,
             params: order,
             timestamp: value(attrs, :timestamp),
             recv_window: value(attrs, :recv_window, @default_recv_window)
           }) do
      {:ok,
       %{
         market: :futures,
         order: order,
         request: request,
         validation: order_validation(order),
         margin: %{
           leverage: value(attrs, :leverage),
           margin_type: value(attrs, :margin_type),
           position_side: Map.get(order, "positionSide")
         }
       }}
    end
  end

  @doc "Builds an order-management request plan for create, cancel, query, or open-order flows."
  def order_management_plan(attrs) when is_map(attrs) do
    action = attrs |> value(:action, :open_orders) |> normalize_action()
    market = attrs |> value(:market, :spot) |> normalize_market()

    case action do
      :new_order ->
        if market == :futures, do: futures_order_plan(attrs), else: spot_order_plan(attrs)

      :cancel_order ->
        rest_request_plan(%{
          market: market,
          endpoint: :cancel_order,
          symbol: value(attrs, :symbol),
          timestamp: value(attrs, :timestamp),
          params: order_lookup_params(attrs)
        })

      :query_order ->
        rest_request_plan(%{
          market: market,
          endpoint: :query_order,
          symbol: value(attrs, :symbol),
          timestamp: value(attrs, :timestamp),
          params: order_lookup_params(attrs)
        })

      :open_orders ->
        rest_request_plan(%{
          market: market,
          endpoint: :open_orders,
          symbol: value(attrs, :symbol),
          timestamp: value(attrs, :timestamp),
          params: value(attrs, :params, %{})
        })

      _unknown ->
        {:error, :unknown_order_management_action}
    end
  end

  @doc "Builds combined Binance WebSocket subscription plans."
  def websocket_plan(attrs) when is_map(attrs) do
    market = attrs |> value(:market, :spot) |> normalize_market()
    subscriptions = attrs |> value(:subscriptions, value(attrs, :streams, [])) |> List.wrap()

    streams = Enum.map(subscriptions, &stream_name/1)
    combined = value(attrs, :combined, true)

    path =
      if combined, do: "/stream?streams=#{Enum.join(streams, "/")}", else: "/ws/#{hd(streams)}"

    {:ok,
     %{
       market: market,
       combined: combined,
       stream_count: length(streams),
       streams: streams,
       url: websocket_url(market) <> path,
       reconnect_policy: %{
         ping_interval_seconds: 180,
         backoff_ms: [250, 1_000, 5_000],
         resubscribe_on_reconnect: true
       }
     }}
  end

  @doc "Normalizes spot balances and futures positions into one portfolio snapshot."
  def portfolio_snapshot(attrs) when is_map(attrs) do
    spot_balances =
      attrs
      |> value(:spot_balances, [])
      |> Enum.map(&normalize_balance/1)
      |> Enum.reject(&(&1.total == 0.0))

    futures_positions =
      attrs
      |> value(:futures_positions, [])
      |> Enum.map(&normalize_position/1)
      |> Enum.reject(&(&1.notional == 0.0 and &1.position_amount == 0.0))

    {:ok,
     %{
       account_id: value(attrs, :account_id),
       spot_balances: spot_balances,
       futures_positions: futures_positions,
       totals: %{
         spot_assets: length(spot_balances),
         futures_positions: length(futures_positions),
         spot_free: sum_float(spot_balances, :free),
         spot_locked: sum_float(spot_balances, :locked),
         futures_unrealized_pnl: sum_float(futures_positions, :unrealized_pnl),
         futures_notional: sum_float(futures_positions, :notional)
       }
     }}
  end

  @doc "Computes request-weight usage and rate-limit compliance."
  def rate_limit_report(requests, opts \\ %{}) when is_list(requests) do
    limit = value(opts, :limit_per_minute, 1_200)
    window = value(opts, :window_seconds, 60)

    rows =
      Enum.map(requests, fn request ->
        market = request |> value(:market, :spot) |> normalize_market()
        endpoint = request |> value(:endpoint) |> normalize_endpoint()
        configured_weight = request |> value(:weight)
        weight = configured_weight || endpoint_weight(market, endpoint)
        count = value(request, :count, 1)

        %{
          market: market,
          endpoint: endpoint,
          count: count,
          weight_each: weight,
          weight_total: count * weight
        }
      end)

    used = sum_int(rows, :weight_total)

    {:ok,
     %{
       limit_per_minute: limit,
       window_seconds: window,
       used_weight: used,
       remaining_weight: max(limit - used, 0),
       compliant: used <= limit,
       utilization: used / max(limit, 1),
       requests: rows,
       recommendations: rate_limit_recommendations(used, limit)
     }}
  end

  @doc "Builds a full Binance exchange plan covering REST, WebSocket, orders, portfolio, and limits."
  def trading_system_plan(attrs) when is_map(attrs) do
    with {:ok, market_data} <- market_data_plans(value(attrs, :market_data, [])),
         {:ok, websocket} <- websocket_plan(value(attrs, :websocket, %{})),
         {:ok, spot_orders} <- order_plans(value(attrs, :spot_orders, []), :spot),
         {:ok, futures_orders} <- order_plans(value(attrs, :futures_orders, []), :futures),
         {:ok, portfolio} <- portfolio_snapshot(value(attrs, :portfolio, %{})),
         {:ok, rate_limits} <-
           rate_limit_report(
             market_data ++ Enum.map(spot_orders ++ futures_orders, & &1.request),
             value(attrs, :rate_limits, %{})
           ) do
      {:ok,
       %{
         market_data: market_data,
         websocket: websocket,
         spot_orders: spot_orders,
         futures_orders: futures_orders,
         portfolio: portfolio,
         rate_limits: rate_limits,
         ready: rate_limits.compliant
       }}
    end
  end

  defp market_data_plans(items) do
    items
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
      case rest_request_plan(item) do
        {:ok, plan} -> {:cont, {:ok, [plan | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, plans} -> {:ok, Enum.reverse(plans)}
      error -> error
    end
  end

  defp order_plans(items, market) do
    items
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
      result = if market == :futures, do: futures_order_plan(item), else: spot_order_plan(item)

      case result do
        {:ok, plan} -> {:cont, {:ok, [plan | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, plans} -> {:ok, Enum.reverse(plans)}
      error -> error
    end
  end

  defp normalize_order(attrs, market) do
    with {:ok, symbol} <- required(attrs, :symbol),
         {:ok, side} <- required(attrs, :side),
         {:ok, type} <- required(attrs, :type) do
      order =
        %{
          "symbol" => normalize_symbol(symbol),
          "side" => side |> to_string() |> String.upcase(),
          "type" => type |> to_string() |> String.upcase(),
          "quantity" => value(attrs, :quantity),
          "price" => value(attrs, :price),
          "timeInForce" => value(attrs, :time_in_force, value(attrs, :timeInForce, "GTC")),
          "newClientOrderId" => client_order_id(attrs, market)
        }
        |> maybe_put("stopPrice", value(attrs, :stop_price))
        |> maybe_put("icebergQty", value(attrs, :iceberg_quantity))
        |> maybe_put("reduceOnly", value(attrs, :reduce_only))
        |> maybe_put("positionSide", value(attrs, :position_side))
        |> maybe_put("workingType", value(attrs, :working_type))
        |> drop_nil_values()
        |> drop_market_only_fields()

      {:ok, order}
    end
  end

  defp order_validation(order) do
    errors =
      []
      |> maybe_add(missing?(order, "quantity"), :missing_quantity)
      |> maybe_add(limit_order?(order) and missing?(order, "price"), :missing_limit_price)
      |> maybe_add(limit_order?(order) and missing?(order, "timeInForce"), :missing_time_in_force)

    %{valid: errors == [], errors: Enum.reverse(errors)}
  end

  defp limit_order?(order),
    do: Map.get(order, "type") in ["LIMIT", "STOP_LOSS_LIMIT", "TAKE_PROFIT_LIMIT"]

  defp missing?(order, key), do: Map.get(order, key) in [nil, ""]

  defp drop_market_only_fields(%{"type" => "MARKET"} = order),
    do: Map.drop(order, ["price", "timeInForce"])

  defp drop_market_only_fields(order), do: order

  defp order_lookup_params(attrs) do
    %{}
    |> maybe_put("orderId", value(attrs, :order_id))
    |> maybe_put("origClientOrderId", value(attrs, :orig_client_order_id))
    |> maybe_put("recvWindow", value(attrs, :recv_window, @default_recv_window))
  end

  defp endpoint_spec(market, endpoint) do
    case get_in(@endpoints, [market, endpoint]) do
      nil -> {:error, {:unknown_endpoint, market, endpoint}}
      spec -> {:ok, spec}
    end
  end

  defp endpoint_weight(market, endpoint), do: get_in(@endpoints, [market, endpoint, :weight]) || 1

  defp maybe_put_symbol(params, attrs) do
    case value(attrs, :symbol) do
      nil -> params
      symbol -> Map.put(params, "symbol", normalize_symbol(symbol))
    end
  end

  defp maybe_put_default_limit(params, :order_book), do: Map.put_new(params, "limit", 100)
  defp maybe_put_default_limit(params, _endpoint), do: params

  defp maybe_put_signed_fields(params, %{signed: true}, attrs) do
    params
    |> Map.put_new("timestamp", value(attrs, :timestamp, "<timestamp>"))
    |> Map.put_new("recvWindow", value(attrs, :recv_window, @default_recv_window))
  end

  defp maybe_put_signed_fields(params, _endpoint_spec, _attrs), do: params

  defp request_url(base_url, path, ""), do: base_url <> path
  defp request_url(base_url, path, query), do: base_url <> path <> "?" <> query

  defp request_headers(true), do: [{"x-mbx-apikey", "<api-key>"}]
  defp request_headers(false), do: []

  defp stream_name(stream) when is_binary(stream), do: String.downcase(stream)

  defp stream_name(stream) when is_map(stream) do
    symbol = stream |> value(:symbol) |> normalize_symbol() |> String.downcase()
    kind = stream |> value(:stream, :ticker) |> normalize_stream_kind()
    "#{symbol}@#{kind}"
  end

  defp normalize_stream_kind(kind) when is_atom(kind),
    do: Map.get(@stream_aliases, kind, Atom.to_string(kind))

  defp normalize_stream_kind(kind) when is_binary(kind) do
    @stream_aliases
    |> Map.get(String.to_atom(String.downcase(kind)), kind)
  rescue
    ArgumentError -> kind
  end

  defp normalize_balance(balance) do
    free = balance |> value(:free, 0) |> to_float()
    locked = balance |> value(:locked, 0) |> to_float()

    %{
      asset: balance |> value(:asset) |> to_string(),
      free: free,
      locked: locked,
      total: free + locked
    }
  end

  defp normalize_position(position) do
    amount = position |> value(:position_amt, value(position, :positionAmt, 0)) |> to_float()
    mark_price = position |> value(:mark_price, value(position, :markPrice, 0)) |> to_float()
    notional = position |> value(:notional, abs(amount * mark_price)) |> to_float()

    %{
      symbol: position |> value(:symbol) |> normalize_symbol(),
      position_amount: amount,
      entry_price: position |> value(:entry_price, value(position, :entryPrice, 0)) |> to_float(),
      mark_price: mark_price,
      notional: notional,
      leverage: position |> value(:leverage, 1) |> to_float(),
      unrealized_pnl:
        position |> value(:unrealized_pnl, value(position, :unRealizedProfit, 0)) |> to_float()
    }
  end

  defp rate_limit_recommendations(used, limit) when used <= limit * 0.8, do: [:within_safe_range]

  defp rate_limit_recommendations(used, limit) when used <= limit,
    do: [:near_limit, :stagger_requests]

  defp rate_limit_recommendations(_used, _limit), do: [:over_limit, :throttle_or_batch]

  defp query_string(params) do
    params
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Enum.map_join("&", fn {key, value} -> "#{key}=#{URI.encode_www_form(to_string(value))}" end)
  end

  defp normalize_params(params) when is_map(params) do
    Map.new(params, fn {key, value} -> {external_key(key), value} end)
  end

  defp external_key(key) when is_atom(key) do
    key
    |> Atom.to_string()
    |> Macro.camelize()
    |> then(fn
      "RecvWindow" ->
        "recvWindow"

      "TimeInForce" ->
        "timeInForce"

      "OrderId" ->
        "orderId"

      "OrigClientOrderId" ->
        "origClientOrderId"

      "NewClientOrderId" ->
        "newClientOrderId"

      "PositionSide" ->
        "positionSide"

      "ReduceOnly" ->
        "reduceOnly"

      "StopPrice" ->
        "stopPrice"

      "WorkingType" ->
        "workingType"

      other ->
        String.replace_prefix(other, String.first(other), String.downcase(String.first(other)))
    end)
  end

  defp external_key(key), do: to_string(key)

  defp normalize_market(:futures), do: :futures
  defp normalize_market("futures"), do: :futures
  defp normalize_market("usd_m_futures"), do: :futures
  defp normalize_market(_market), do: :spot

  defp normalize_endpoint(endpoint) when is_atom(endpoint), do: endpoint

  defp normalize_endpoint(endpoint) when is_binary(endpoint),
    do: endpoint |> String.downcase() |> String.to_atom()

  defp normalize_endpoint(endpoint), do: endpoint

  defp normalize_action(action) when is_atom(action), do: action

  defp normalize_action(action) when is_binary(action),
    do: action |> String.downcase() |> String.to_atom()

  defp normalize_action(action), do: action

  defp normalize_symbol(nil), do: nil

  defp normalize_symbol(symbol),
    do: symbol |> to_string() |> String.replace("/", "") |> String.upcase()

  defp client_order_id(attrs, market) do
    value(attrs, :client_order_id) ||
      value(attrs, :new_client_order_id) ||
      "lux-#{market}-#{normalize_symbol(value(attrs, :symbol))}-#{System.unique_integer([:positive])}"
  end

  defp base_url(:futures), do: @futures_base_url
  defp base_url(_market), do: @spot_base_url

  defp websocket_url(:futures), do: @futures_ws_url
  defp websocket_url(_market), do: @spot_ws_url

  defp required(map, key) do
    case value(map, key) do
      nil -> {:error, {:missing_required, key}}
      found -> {:ok, found}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp drop_nil_values(map), do: Map.reject(map, fn {_key, value} -> is_nil(value) end)

  defp sum_float(items, key), do: items |> Enum.map(&Map.fetch!(&1, key)) |> Enum.sum()
  defp sum_int(items, key), do: items |> Enum.map(&Map.fetch!(&1, key)) |> Enum.sum()

  defp to_float(value) when is_float(value), do: value
  defp to_float(value) when is_integer(value), do: value / 1

  defp to_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _rest} -> float
      :error -> 0.0
    end
  end

  defp to_float(_value), do: 0.0

  defp maybe_add(list, true, value), do: [value | list]
  defp maybe_add(list, false, _value), do: list

  defp value(map, key, default \\ nil)

  defp value(map, key, default) when is_map(map),
    do: Map.get(map, key, Map.get(map, to_string(key), default))

  defp value(_map, _key, default), do: default
end
