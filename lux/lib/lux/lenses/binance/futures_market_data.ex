defmodule Lux.Lenses.Binance.FuturesMarketData do
  @moduledoc """
  Lens for Binance Futures market data: funding rates, mark price, open interest, and liquidations.
  """

  @base_url "https://fapi.binance.com"

  def focus(params, _opts \\ []) do
    action = params[:action] || params["action"] || "funding_rate"
    symbol = params[:symbol] || params["symbol"]
    plug = params[:plug]

    case action do
      "funding_rate" -> get_funding_rate(symbol, plug)
      "mark_price" -> get_mark_price(symbol, plug)
      "open_interest" -> get_open_interest(symbol, plug)
      "liquidations" -> get_liquidations(symbol, plug)
      "klines" -> get_klines(symbol, params[:interval] || "1h", params[:limit] || 100, plug)
      _ -> {:error, "Unknown action: #{action}"}
    end
  end

  defp get_funding_rate(symbol, plug) do
    params = if symbol, do: %{"symbol" => symbol, "limit" => "10"}, else: %{"limit" => "10"}
    case api_get("/fapi/v1/fundingRate", params, plug) do
      {:ok, rates} when is_list(rates) ->
        parsed = Enum.map(rates, fn r ->
          %{
            symbol: r["symbol"],
            funding_rate: parse_float(r["fundingRate"]),
            funding_time: r["fundingTime"],
            mark_price: parse_float(r["markPrice"])
          }
        end)
        {:ok, %{funding_rates: parsed, count: length(parsed)}}
      error -> error
    end
  end

  defp get_mark_price(symbol, plug) do
    params = if symbol, do: %{"symbol" => symbol}, else: %{}
    case api_get("/fapi/v1/premiumIndex", params, plug) do
      {:ok, data} ->
        items = if is_list(data), do: data, else: [data]
        parsed = Enum.map(items, fn d ->
          %{
            symbol: d["symbol"],
            mark_price: parse_float(d["markPrice"]),
            index_price: parse_float(d["indexPrice"]),
            last_funding_rate: parse_float(d["lastFundingRate"]),
            next_funding_time: d["nextFundingTime"],
            interest_rate: parse_float(d["interestRate"])
          }
        end)
        {:ok, %{prices: parsed}}
      error -> error
    end
  end

  defp get_open_interest(symbol, plug) do
    case api_get("/fapi/v1/openInterest", %{"symbol" => symbol || "BTCUSDT"}, plug) do
      {:ok, data} ->
        {:ok, %{
          symbol: data["symbol"],
          open_interest: parse_float(data["openInterest"]),
          time: data["time"]
        }}
      error -> error
    end
  end

  defp get_liquidations(symbol, plug) do
    params = %{"limit" => "50"}
    params = if symbol, do: Map.put(params, "symbol", symbol), else: params
    case api_get("/fapi/v1/allForceOrders", params, plug) do
      {:ok, orders} when is_list(orders) ->
        parsed = Enum.map(orders, fn o ->
          %{
            symbol: o["symbol"],
            side: o["side"],
            type: o["orderType"],
            quantity: parse_float(o["origQty"]),
            price: parse_float(o["price"]),
            avg_price: parse_float(o["averagePrice"]),
            status: o["status"],
            time: o["time"]
          }
        end)
        {:ok, %{liquidations: parsed, count: length(parsed)}}
      error -> error
    end
  end

  defp get_klines(symbol, interval, limit, plug) do
    case api_get("/fapi/v1/klines", %{"symbol" => symbol || "BTCUSDT", "interval" => interval, "limit" => "#{limit}"}, plug) do
      {:ok, data} when is_list(data) ->
        parsed = Enum.map(data, fn k ->
          %{
            open_time: Enum.at(k, 0), open: parse_float(Enum.at(k, 1)),
            high: parse_float(Enum.at(k, 2)), low: parse_float(Enum.at(k, 3)),
            close: parse_float(Enum.at(k, 4)), volume: parse_float(Enum.at(k, 5)),
            close_time: Enum.at(k, 6)
          }
        end)
        {:ok, %{klines: parsed, count: length(parsed)}}
      error -> error
    end
  end

  defp api_get(path, params, plug) do
    url = @base_url <> path
    query = URI.encode_query(params)
    full_url = if query != "", do: "#{url}?#{query}", else: url

    req_opts = [url: full_url, method: :get, retry: false]
    req_opts = if plug, do: Keyword.put(req_opts, :plug, plug), else: req_opts

    case Req.request(req_opts) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{body: body}} -> {:error, body}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_float(nil), do: 0.0
  defp parse_float(s) when is_binary(s) do
    case Float.parse(s) do
      {f, _} -> f
      :error -> 0.0
    end
  end
  defp parse_float(n) when is_number(n), do: n * 1.0
end
