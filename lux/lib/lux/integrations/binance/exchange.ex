defmodule Lux.Integrations.Binance.Exchange do
  @moduledoc """
  Binance spot and futures exchange request-planning helpers.

  This module does not store API keys, create signatures, submit live orders, or
  open WebSocket connections. It builds deterministic REST/WebSocket plans,
  normalizes order payloads, summarizes account state, and estimates Binance
  request-weight usage so prisms, lenses, and client adapters can enforce the
  exchange contract safely.
  """

  @spot_rest "https://api.binance.com"
  @futures_rest "https://fapi.binance.com"
  @spot_ws "wss://stream.binance.com:9443"
  @futures_ws "wss://fstream.binance.com"

  @public_endpoints %{
    exchange_info: {"/api/v3/exchangeInfo", "/fapi/v1/exchangeInfo", 10},
    ticker_price: {"/api/v3/ticker/price", "/fapi/v1/ticker/price", 2},
    ticker_24h: {"/api/v3/ticker/24hr", "/fapi/v1/ticker/24hr", 2},
    order_book: {"/api/v3/depth", "/fapi/v1/depth", 5},
    klines: {"/api/v3/klines", "/fapi/v1/klines", 2}
  }

  @signed_endpoints %{
    account: {:get, "/api/v3/account", "/fapi/v2/account", 20},
    open_orders: {:get, "/api/v3/openOrders", "/fapi/v1/openOrders", 6},
    create_order: {:post, "/api/v3/order", "/fapi/v1/order", 1},
    cancel_order: {:delete, "/api/v3/order", "/fapi/v1/order", 1}
  }

  @doc """
  Builds a public REST request plan for Binance spot or futures market data.
  """
  @spec market_request(:spot | :futures, atom(), map()) :: {:ok, map()} | {:error, String.t()}
  def market_request(market, request, attrs \\ %{}) do
    with {:ok, endpoint, weight} <- public_endpoint(market, request),
         {:ok, params} <- public_params(request, attrs) do
      {:ok,
       %{
         market: market,
         method: :get,
         base_url: rest_base(market),
         endpoint: endpoint,
         url: rest_base(market) <> endpoint,
         params: params,
         weight: weight,
         security_type: :none
       }}
    end
  end

  @doc """
  Builds a signed REST request plan without computing the HMAC signature.
  """
  @spec signed_request(:spot | :futures, atom(), map()) :: {:ok, map()} | {:error, String.t()}
  def signed_request(market, action, attrs) when is_map(attrs) do
    with {:ok, method, endpoint, weight} <- signed_endpoint(market, action),
         {:ok, params} <- signed_params(action, attrs) do
      query = canonical_query(params)

      {:ok,
       %{
         market: market,
         action: action,
         method: method,
         base_url: rest_base(market),
         endpoint: endpoint,
         url: rest_base(market) <> endpoint,
         params: params,
         query_to_sign: query,
         headers: api_key_headers(attrs),
         weight: weight,
         security_type: :signed
       }}
    end
  end

  @doc """
  Normalizes an order into Binance API parameters.
  """
  @spec order_plan(map()) :: {:ok, map()} | {:error, String.t()}
  def order_plan(attrs) when is_map(attrs) do
    symbol = attrs |> value(:symbol) |> normalize_symbol()
    side = attrs |> value(:side) |> normalize_side()
    type = attrs |> value(:type) |> normalize_order_type()
    quantity = number(attrs, :quantity)

    cond do
      symbol == "" ->
        {:error, "Missing Binance symbol"}

      is_nil(side) ->
        {:error, "Unsupported Binance order side"}

      is_nil(type) ->
        {:error, "Unsupported Binance order type"}

      quantity <= 0 ->
        {:error, "Order quantity must be positive"}

      true ->
        {:ok,
         %{
           symbol: symbol,
           side: side,
           type: type,
           quantity: quantity,
           price: optional_number(attrs, :price),
           time_in_force: time_in_force(attrs, type),
           reduce_only: value(attrs, :reduce_only) || false,
           position_side: position_side(attrs),
           client_order_id: value(attrs, :client_order_id)
         }
         |> reject_nil_values()}
    end
  end

  @doc """
  Builds WebSocket stream subscription plans.
  """
  @spec websocket_plan(:spot | :futures, [map() | String.t()]) ::
          {:ok, map()} | {:error, String.t()}
  def websocket_plan(market, streams) when is_list(streams) do
    normalized = streams |> Enum.map(&stream_name/1) |> Enum.reject(&(&1 == ""))

    if normalized == [] do
      {:error, "At least one Binance stream is required"}
    else
      {:ok,
       %{
         market: market,
         base_url: websocket_base(market),
         streams: normalized,
         url: websocket_base(market) <> "/stream?streams=" <> Enum.join(normalized, "/")
       }}
    end
  end

  @doc """
  Estimates REST weight consumption for request plans.
  """
  @spec weight_summary([map()], map()) :: map()
  def weight_summary(requests, policy \\ %{}) do
    limit = value(policy, :limit_per_minute) || 1_200
    total = requests |> Enum.map(&(value(&1, :weight) || 1)) |> Enum.sum()

    %{
      request_count: length(requests),
      used_weight: total,
      limit_per_minute: limit,
      remaining_weight: max(limit - total, 0),
      allowed?: total <= limit,
      utilization: ratio(total, limit)
    }
  end

  @doc """
  Summarizes spot balances and futures positions.
  """
  @spec portfolio_snapshot(map()) :: map()
  def portfolio_snapshot(attrs) when is_map(attrs) do
    balances = attrs |> value(:balances) |> List.wrap() |> Enum.map(&balance_snapshot/1)
    positions = attrs |> value(:positions) |> List.wrap() |> Enum.map(&position_snapshot/1)

    %{
      balances: balances,
      positions: positions,
      total_free: balances |> Enum.map(& &1.free) |> Enum.sum(),
      total_locked: balances |> Enum.map(& &1.locked) |> Enum.sum(),
      unrealized_pnl: positions |> Enum.map(& &1.unrealized_pnl) |> Enum.sum(),
      open_position_count: Enum.count(positions, &(&1.size != 0.0))
    }
  end

  defp public_endpoint(market, request) do
    case Map.fetch(@public_endpoints, request) do
      {:ok, {spot, futures, weight}} -> {:ok, endpoint_for_market(market, spot, futures), weight}
      :error -> {:error, "Unsupported Binance market data request: #{request}"}
    end
  end

  defp signed_endpoint(market, action) do
    case Map.fetch(@signed_endpoints, action) do
      {:ok, {method, spot, futures, weight}} ->
        {:ok, method, endpoint_for_market(market, spot, futures), weight}

      :error ->
        {:error, "Unsupported Binance signed request: #{action}"}
    end
  end

  defp endpoint_for_market(:spot, spot, _futures), do: spot
  defp endpoint_for_market(:futures, _spot, futures), do: futures
  defp endpoint_for_market(market, _spot, _futures) do
    raise ArgumentError, "Bad market #{market}"
  end

  defp public_params(:exchange_info, attrs), do: {:ok, only_present(attrs, [:symbol, :symbols])}
  defp public_params(:ticker_price, attrs), do: {:ok, only_present(attrs, [:symbol])}
  defp public_params(:ticker_24h, attrs), do: {:ok, only_present(attrs, [:symbol])}

  defp public_params(:order_book, attrs) do
    {:ok, only_present(attrs, [:symbol, :limit])}
  end

  defp public_params(:klines, attrs) do
    required = [:symbol, :interval]

    if Enum.all?(required, &present?(value(attrs, &1))) do
      {:ok, only_present(attrs, required ++ [:start_time, :end_time, :limit])}
    else
      {:error, "Kline requests require symbol and interval"}
    end
  end

  defp signed_params(:create_order, attrs) do
    with {:ok, order} <- order_plan(attrs) do
      {:ok, signed_common(attrs) |> Map.merge(order_params(order))}
    end
  end

  defp signed_params(_action, attrs) do
    {:ok, signed_common(attrs) |> Map.merge(only_present(attrs, [:symbol, :order_id]))}
  end

  defp signed_common(attrs) do
    %{
      timestamp: value(attrs, :timestamp) || now_ms(attrs),
      recvWindow: value(attrs, :recv_window) || 5_000
    }
  end

  defp now_ms(attrs), do: value(attrs, :now_ms) || 0

  defp api_key_headers(attrs) do
    case value(attrs, :api_key) do
      nil -> []
      api_key -> [{"X-MBX-APIKEY", api_key}]
    end
  end

  defp stream_name(stream) when is_binary(stream), do: String.downcase(stream)

  defp stream_name(stream) when is_map(stream) do
    symbol = stream |> value(:symbol) |> normalize_symbol() |> String.downcase()
    channel = value(stream, :channel) || "ticker"
    interval = value(stream, :interval)

    [symbol, "@", channel, interval_suffix(interval)] |> IO.iodata_to_binary()
  end

  defp interval_suffix(nil), do: ""
  defp interval_suffix(interval), do: "_#{interval}"

  defp rest_base(:spot), do: @spot_rest
  defp rest_base(:futures), do: @futures_rest

  defp websocket_base(:spot), do: @spot_ws
  defp websocket_base(:futures), do: @futures_ws

  defp normalize_symbol(nil), do: ""
  defp normalize_symbol(symbol), do: symbol |> to_string() |> String.upcase()

  defp normalize_side(side) when side in [:buy, "buy", "BUY"], do: "BUY"
  defp normalize_side(side) when side in [:sell, "sell", "SELL"], do: "SELL"
  defp normalize_side(_side), do: nil

  defp normalize_order_type(type) when type in [:market, "market", "MARKET"], do: "MARKET"
  defp normalize_order_type(type) when type in [:limit, "limit", "LIMIT"], do: "LIMIT"
  defp normalize_order_type(type) when type in [:stop_loss, "stop_loss", "STOP_LOSS"] do
    "STOP_LOSS"
  end
  defp normalize_order_type(_type), do: nil

  defp time_in_force(attrs, "LIMIT"), do: value(attrs, :time_in_force) || "GTC"
  defp time_in_force(_attrs, _type), do: nil

  defp position_side(attrs) do
    case value(attrs, :position_side) do
      side when side in [:long, "long", "LONG"] -> "LONG"
      side when side in [:short, "short", "SHORT"] -> "SHORT"
      side when side in [:both, "both", "BOTH"] -> "BOTH"
      _other -> nil
    end
  end

  defp balance_snapshot(balance) do
    %{
      asset: value(balance, :asset),
      free: number(balance, :free),
      locked: number(balance, :locked)
    }
  end

  defp position_snapshot(position) do
    %{
      symbol: value(position, :symbol),
      size: number(position, :position_amt),
      entry_price: number(position, :entry_price),
      mark_price: number(position, :mark_price),
      unrealized_pnl: number(position, :unrealized_pnl),
      leverage: number(position, :leverage)
    }
  end

  defp canonical_query(params) do
    params
    |> reject_nil_values()
    |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
    |> Enum.map(fn {key, value} -> "#{key}=#{value}" end)
    |> Enum.join("&")
  end

  defp only_present(attrs, keys) do
    keys
    |> Map.new(fn key -> {external_key(key), external_value(key, value(attrs, key))} end)
    |> reject_nil_values()
  end

  defp order_params(order) do
    order
    |> Map.new(fn {key, value} -> {external_key(key), value} end)
    |> reject_nil_values()
  end

  defp external_key(:start_time), do: :startTime
  defp external_key(:end_time), do: :endTime
  defp external_key(:order_id), do: :orderId
  defp external_key(:time_in_force), do: :timeInForce
  defp external_key(:reduce_only), do: :reduceOnly
  defp external_key(:position_side), do: :positionSide
  defp external_key(:client_order_id), do: :newClientOrderId
  defp external_key(key), do: key

  defp external_value(:symbol, value), do: normalize_symbol(value)
  defp external_value(_key, value), do: value

  defp reject_nil_values(map), do: Map.reject(map, fn {_key, value} -> is_nil(value) end)

  defp optional_number(map, key) do
    case value(map, key) do
      nil -> nil
      _value -> number(map, key)
    end
  end

  defp number(map, key) do
    case value(map, key) do
      value when is_integer(value) -> value * 1.0
      value when is_float(value) -> value

      value when is_binary(value) ->
        case Float.parse(value) do
          {parsed, _rest} -> parsed
          :error -> 0.0
        end

      _other ->
        0.0
    end
  end

  defp ratio(_numerator, 0), do: 0.0
  defp ratio(numerator, denominator), do: numerator / denominator

  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?(_value), do: true

  defp value(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp value(_map, _key), do: nil
end
