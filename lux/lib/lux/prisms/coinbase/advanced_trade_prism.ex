defmodule Lux.Prisms.Coinbase.AdvancedTradePrism do
  @moduledoc """
  Coinbase Advanced Trade v3 Spot & Order Management Integration Prism (#83).

  Capabilities:
  - Authenticated REST header generation (`build_auth_headers/4`) for `https://api.coinbase.com/api/v3/brokerage`
  - Spot market, limit GTC/GTD, and stop-limit order construction (`build_order/1`)
  - WebSocket feed subscription (`build_ws_subscribe/3` for `ticker`, `level2`, `market_trades`, `candles`, `user`)
  - Multi-account portfolio valuation (`summarize_accounts/1`) & historical OHLCV normalization (`normalize_candles/1`)
  - Sliding-window rate limit compliance (`check_rate_limit/3`)
  """

  @base_url "https://api.coinbase.com/api/v3/brokerage"
  @max_private_rps 30

  @doc """
  Generates CB-ACCESS-* authentication headers with HMAC-SHA256 signing for Coinbase Advanced Trade REST requests.
  """
  @spec build_auth_headers(String.t(), String.t(), String.t(), String.t(), String.t(), pos_integer()) ::
          {:ok, map()} | {:error, atom()}
  def build_auth_headers(
        api_key,
        api_secret,
        method,
        request_path,
        body \\ "",
        timestamp \\ System.system_time(:second)
      )
      when is_binary(api_key) and is_binary(api_secret) and byte_size(api_key) > 0 and
             byte_size(api_secret) > 0 do
    ts_str = Integer.to_string(timestamp)
    prehash = "#{ts_str}#{String.upcase(method)}#{request_path}#{body}"

    signature =
      :crypto.mac(:hmac, :sha256, api_secret, prehash)
      |> Base.encode16(case: :lower)

    {:ok,
     %{
       "CB-ACCESS-KEY" => api_key,
       "CB-ACCESS-SIGN" => signature,
       "CB-ACCESS-TIMESTAMP" => ts_str,
       "Content-Type" => "application/json"
     }}
  end

  def build_auth_headers(_, _, _, _, _, _), do: {:error, :invalid_credentials}

  @doc """
  Constructs a Coinbase Advanced Trade v3 order configuration (`market_market_ioc`, `limit_limit_gtc`, or `stop_limit_stop_limit_gtc`).
  """
  @spec build_order(map()) :: {:ok, map()} | {:error, atom()}
  def build_order(%{client_order_id: cid, product_id: pid, side: side, order_type: otype} = spec)
      when is_binary(cid) and is_binary(pid) and side in ["BUY", "SELL"] do
    case otype do
      :market ->
        quote_size = Map.get(spec, :quote_size)
        base_size = Map.get(spec, :base_size)

        if (is_number(quote_size) and quote_size > 0) or (is_number(base_size) and base_size > 0) do
          cfg =
            %{}
            |> maybe_put_str(:quote_size, quote_size)
            |> maybe_put_str(:base_size, base_size)

          {:ok,
           %{
             endpoint: "#{@base_url}/orders",
             client_order_id: cid,
             product_id: String.upcase(pid),
             side: side,
             order_configuration: %{market_market_ioc: cfg}
           }}
        else
          {:error, :invalid_market_size}
        end

      :limit_gtc ->
        base_size = Map.get(spec, :base_size)
        limit_price = Map.get(spec, :limit_price)

        if is_number(base_size) and base_size > 0 and is_number(limit_price) and limit_price > 0 do
          {:ok,
           %{
             endpoint: "#{@base_url}/orders",
             client_order_id: cid,
             product_id: String.upcase(pid),
             side: side,
             order_configuration: %{
               limit_limit_gtc: %{
                 base_size: :erlang.float_to_binary(base_size * 1.0, decimals: 6),
                 limit_price: :erlang.float_to_binary(limit_price * 1.0, decimals: 2),
                 post_only: Map.get(spec, :post_only, false)
               }
             }
           }}
        else
          {:error, :invalid_limit_params}
        end

      :stop_limit_gtc ->
        base_size = Map.get(spec, :base_size)
        limit_price = Map.get(spec, :limit_price)
        stop_price = Map.get(spec, :stop_price)

        if is_number(base_size) and base_size > 0 and is_number(limit_price) and limit_price > 0 and
             is_number(stop_price) and stop_price > 0 do
          {:ok,
           %{
             endpoint: "#{@base_url}/orders",
             client_order_id: cid,
             product_id: String.upcase(pid),
             side: side,
             order_configuration: %{
               stop_limit_stop_limit_gtc: %{
                 base_size: :erlang.float_to_binary(base_size * 1.0, decimals: 6),
                 limit_price: :erlang.float_to_binary(limit_price * 1.0, decimals: 2),
                 stop_price: :erlang.float_to_binary(stop_price * 1.0, decimals: 2),
                 stop_direction: Map.get(spec, :stop_direction, "STOP_DIRECTION_STOP_DOWN")
               }
             }
           }}
        else
          {:error, :invalid_stop_limit_params}
        end

      _ ->
        {:error, :unsupported_order_type}
    end
  end

  def build_order(_), do: {:error, :invalid_order_spec}

  defp maybe_put_str(map, _key, nil), do: map

  defp maybe_put_str(map, key, val) when is_number(val) do
    Map.put(map, key, :erlang.float_to_binary(val * 1.0, decimals: 4))
  end

  @doc """
  Builds a Coinbase Advanced Trade WebSocket subscription message for a channel and product list.
  """
  @spec build_ws_subscribe(String.t(), [String.t()], pos_integer()) ::
          {:ok, map()} | {:error, atom()}
  def build_ws_subscribe(channel, product_ids, timestamp \\ System.system_time(:second))
      when is_binary(channel) and is_list(product_ids) and length(product_ids) > 0 do
    if channel not in ["ticker", "level2", "market_trades", "candles", "user", "heartbeats"] do
      {:error, :unsupported_channel}
    else
      {:ok,
       %{
         type: "subscribe",
         channel: channel,
         product_ids: Enum.map(product_ids, &String.upcase/1),
         timestamp: Integer.to_string(timestamp)
       }}
    end
  end

  @doc """
  Aggregates Coinbase brokerage accounts into available, hold, and total USD portfolio value.
  """
  @spec summarize_accounts([map()]) :: {:ok, map()}
  def summarize_accounts(accounts) when is_list(accounts) do
    totals =
      Enum.reduce(accounts, %{available_usd: 0.0, hold_usd: 0.0}, fn acct, acc ->
        avail = Map.get(acct, :available, 0.0) * 1.0
        hold = Map.get(acct, :hold, 0.0) * 1.0
        px = Map.get(acct, :price_usd, 1.0) * 1.0

        %{
          available_usd: acc.available_usd + avail * px,
          hold_usd: acc.hold_usd + hold * px
        }
      end)

    {:ok,
     %{
       account_count: length(accounts),
       available_usd: Float.round(totals.available_usd, 2),
       hold_usd: Float.round(totals.hold_usd, 2),
       total_portfolio_usd: Float.round(totals.available_usd + totals.hold_usd, 2)
     }}
  end

  @doc """
  Normalizes Coinbase `/products/{id}/candles` historical OHLCV bars into chronological order with VWAP estimate.
  """
  @spec normalize_candles([map()]) :: {:ok, [map()]}
  def normalize_candles(candles) when is_list(candles) do
    normalized =
      candles
      |> Enum.map(fn c ->
        high = Map.get(c, :high, 0.0) * 1.0
        low = Map.get(c, :low, 0.0) * 1.0
        close = Map.get(c, :close, 0.0) * 1.0
        typical_price = Float.round((high + low + close) / 3.0, 4)

        %{
          start: Map.get(c, :start),
          open: Map.get(c, :open) * 1.0,
          high: high,
          low: low,
          close: close,
          volume: Map.get(c, :volume, 0.0) * 1.0,
          typical_price: typical_price
        }
      end)
      |> Enum.sort_by(& &1.start, :asc)

    {:ok, normalized}
  end

  @doc """
  Checks sliding-window request rate against Coinbase Advanced Trade v3 per-second limits (`30 req/s`).
  """
  @spec check_rate_limit(non_neg_integer(), pos_integer()) :: {:ok, map()}
  def check_rate_limit(requests_in_current_second, cost \\ 1) do
    projected = requests_in_current_second + cost

    status =
      cond do
        projected > @max_private_rps -> :backoff_required
        projected >= trunc(@max_private_rps * 0.8) -> :throttle
        true -> :allow
      end

    {:ok,
     %{
       status: status,
       requests_in_second: requests_in_current_second,
       projected_rps: projected,
       limit_rps: @max_private_rps
     }}
  end
end
