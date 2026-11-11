defmodule Lux.Prisms.Binance.ExchangePrism do
  @moduledoc """
  Binance Spot & USD-M Perpetual Futures Exchange Integration Prism (#84).

  Capabilities:
  - HMAC-SHA256 request signing (`sign_request/3`) for Spot (`/api/v3/*`) and Futures (`/fapi/v1/*`)
  - Spot & USD-M Futures order validation and payload construction (`build_spot_order/1`, `build_futures_order/1`)
  - WebSocket multiplexed stream subscription builder (`build_ws_subscription/2`)
  - Portfolio & futures cross/isolated margin summary (`summarize_portfolio/2`)
  - Request weight (`X-MBX-USED-WEIGHT-1M`) and order rate limit compliance (`check_rate_limit/3`)
  """

  @spot_base_url "https://api.binance.com"
  @futures_base_url "https://fapi.binance.com"
  @max_weight_per_minute 1200
  @max_orders_per_10s 50

  @doc """
  Computes the canonical query string and HMAC-SHA256 signature for Binance signed endpoints.
  """
  @spec sign_request(map(), String.t(), pos_integer()) :: {:ok, map()} | {:error, atom()}
  def sign_request(params, api_secret, recv_window \\ 5000)
      when is_map(params) and is_binary(api_secret) and byte_size(api_secret) > 0 do
    timestamp = Map.get(params, :timestamp, System.system_time(:millisecond))

    enriched =
      params
      |> Map.put(:timestamp, timestamp)
      |> Map.put_new(:recvWindow, recv_window)

    query_string =
      enriched
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
      |> Enum.sort()
      |> Enum.join("&")

    signature =
      :crypto.mac(:hmac, :sha256, api_secret, query_string)
      |> Base.encode16(case: :lower)

    {:ok,
     %{
       query_string: query_string,
       signature: signature,
       signed_query: "#{query_string}&signature=#{signature}"
     }}
  end

  def sign_request(_, _, _), do: {:error, :invalid_credentials}

  @doc """
  Builds and validates a Binance Spot order (`/api/v3/order`) for `LIMIT`, `MARKET`, or `STOP_LOSS_LIMIT`.
  """
  @spec build_spot_order(map()) :: {:ok, map()} | {:error, atom()}
  def build_spot_order(%{symbol: symbol, side: side, type: type, quantity: qty} = order)
      when is_binary(symbol) and side in ["BUY", "SELL"] and is_number(qty) and qty > 0 do
    cond do
      type not in ["LIMIT", "MARKET", "STOP_LOSS_LIMIT"] ->
        {:error, :unsupported_order_type}

      type in ["LIMIT", "STOP_LOSS_LIMIT"] and
          (not is_number(order[:price]) or order[:price] <= 0) ->
        {:error, :missing_limit_price}

      true ->
        base_payload = %{
          endpoint: "#{@spot_base_url}/api/v3/order",
          symbol: String.upcase(symbol),
          side: side,
          type: type,
          quantity: Float.round(qty * 1.0, 6),
          timeInForce: Map.get(order, :time_in_force, if(type == "MARKET", do: nil, else: "GTC"))
        }

        payload =
          if order[:price],
            do: Map.put(base_payload, :price, Float.round(order[:price] * 1.0, 4)),
            else: base_payload

        {:ok, payload}
    end
  end

  def build_spot_order(_), do: {:error, :invalid_spot_order}

  @doc """
  Builds and validates a Binance USD-M Perpetual Futures order (`/fapi/v1/order`).
  """
  @spec build_futures_order(map()) :: {:ok, map()} | {:error, atom()}
  def build_futures_order(%{symbol: symbol, side: side, type: type, quantity: qty} = order)
      when is_binary(symbol) and side in ["BUY", "SELL"] and is_number(qty) and qty > 0 do
    leverage = Map.get(order, :leverage, 5)

    cond do
      leverage < 1 or leverage > 125 ->
        {:error, :invalid_leverage}

      type == "LIMIT" and (not is_number(order[:price]) or order[:price] <= 0) ->
        {:error, :missing_limit_price}

      true ->
        {:ok,
         %{
           endpoint: "#{@futures_base_url}/fapi/v1/order",
           symbol: String.upcase(symbol),
           side: side,
           type: type,
           quantity: Float.round(qty * 1.0, 6),
           price: if(order[:price], do: Float.round(order[:price] * 1.0, 4), else: nil),
           leverage: leverage,
           reduceOnly: Map.get(order, :reduce_only, false),
           positionSide: Map.get(order, :position_side, "BOTH")
         }}
    end
  end

  def build_futures_order(_), do: {:error, :invalid_futures_order}

  @doc """
  Constructs a Binance WebSocket stream subscription frame (`SUBSCRIBE`) for market data feeds.
  """
  @spec build_ws_subscription([String.t()], pos_integer()) :: {:ok, map()} | {:error, atom()}
  def build_ws_subscription(streams, request_id \\ 1)
      when is_list(streams) and length(streams) > 0 and is_integer(request_id) do
    normalized = Enum.map(streams, &String.downcase/1)

    {:ok,
     %{
       method: "SUBSCRIBE",
       params: normalized,
       id: request_id
     }}
  end

  def build_ws_subscription(_, _), do: {:error, :empty_streams}

  @doc """
  Summarizes Spot asset balances and Futures positions into unified USD equity and margin utilization.
  """
  @spec summarize_portfolio([map()], [map()]) :: {:ok, map()}
  def summarize_portfolio(spot_balances, futures_positions)
      when is_list(spot_balances) and is_list(futures_positions) do
    spot_usd =
      Enum.reduce(spot_balances, 0.0, fn b, acc ->
        free = Map.get(b, :free, 0.0) * 1.0
        locked = Map.get(b, :locked, 0.0) * 1.0
        px = Map.get(b, :price_usd, 0.0) * 1.0
        acc + (free + locked) * px
      end)

    futures_upnl =
      Enum.reduce(futures_positions, 0.0, fn p, acc ->
        acc + Map.get(p, :unrealized_pnl_usd, 0.0) * 1.0
      end)

    {:ok,
     %{
       spot_equity_usd: Float.round(spot_usd, 2),
       futures_unrealized_pnl_usd: Float.round(futures_upnl, 2),
       total_equity_usd: Float.round(spot_usd + futures_upnl, 2),
       open_futures_positions: length(futures_positions)
     }}
  end

  @doc """
  Evaluates Binance request weight (`X-MBX-USED-WEIGHT-1M`) and 10-second order count against limits.
  """
  @spec check_rate_limit(non_neg_integer(), non_neg_integer(), pos_integer()) :: {:ok, map()}
  def check_rate_limit(used_weight_1m, order_count_10s, next_request_weight \\ 1) do
    projected_weight = used_weight_1m + next_request_weight
    weight_utilization = projected_weight / @max_weight_per_minute
    order_utilization = order_count_10s / @max_orders_per_10s

    action =
      cond do
        projected_weight > @max_weight_per_minute or order_count_10s >= @max_orders_per_10s ->
          :backoff_required

        weight_utilization >= 0.85 or order_utilization >= 0.85 ->
          :throttle

        true ->
          :allow
      end

    {:ok,
     %{
       action: action,
       used_weight_1m: used_weight_1m,
       projected_weight_1m: projected_weight,
       order_count_10s: order_count_10s,
       weight_utilization_pct: Float.round(weight_utilization * 100.0, 2)
     }}
  end
end
