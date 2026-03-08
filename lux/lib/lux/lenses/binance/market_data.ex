defmodule Lux.Lenses.Binance.MarketData do
  @moduledoc """
  A lens for fetching market data from the Binance API.
  """

  alias Lux.Integrations.Binance
  alias Lux.Integrations.Binance.Client

  use Lux.Lens,
    name: "Binance Market Data",
    description: "Fetches market data (ticker, orderbook, klines) from Binance",
    url: "#{Binance.spot_base_url()}/api/v3/ticker/price",
    method: :get,
    headers: Binance.headers(),
    schema: %{
      type: :object,
      properties: %{
        endpoint: %{type: :string, enum: ["ticker", "depth", "klines", "ticker_24h"]},
        symbol: %{type: :string},
        interval: %{type: :string, enum: ["1m","3m","5m","15m","30m","1h","2h","4h","6h","8h","12h","1d","3d","1w","1M"]},
        limit: %{type: :integer},
        futures: %{type: :boolean}
      },
      required: ["endpoint", "symbol"]
    }

  @impl true
  def before_focus(params), do: %{url: Binance.spot_base_url(), params: params}

  @impl true
  def after_focus(%{"params" => params}), do: fetch(params)
  def after_focus(params) when is_map(params), do: fetch(params)

  defp fetch(params) do
    endpoint = to_string(params[:endpoint] || params["endpoint"])
    symbol = params[:symbol] || params["symbol"]
    futures = params[:futures] || params["futures"] || false
    limit = params[:limit] || params["limit"]
    interval = params[:interval] || params["interval"]
    plug = params[:plug] || params["plug"]

    {path, qp} = build_req(endpoint, symbol, limit, interval, futures)
    opts = %{params: qp, futures: futures}
    opts = if plug, do: Map.put(opts, :plug, plug), else: opts

    case Client.request(:get, path, opts) do
      {:ok, data} -> format(endpoint, data)
      {:error, e} -> {:error, e}
    end
  end

  defp build_req("ticker", sym, _, _, false), do: {"/api/v3/ticker/price", %{symbol: sym}}
  defp build_req("ticker", sym, _, _, true), do: {"/fapi/v1/ticker/price", %{symbol: sym}}
  defp build_req("depth", sym, lim, _, false), do: {"/api/v3/depth", maybe_limit(%{symbol: sym}, lim)}
  defp build_req("depth", sym, lim, _, true), do: {"/fapi/v1/depth", maybe_limit(%{symbol: sym}, lim)}
  defp build_req("klines", sym, lim, int, false), do: {"/api/v3/klines", maybe_limit(%{symbol: sym, interval: int || "1h"}, lim)}
  defp build_req("klines", sym, lim, int, true), do: {"/fapi/v1/klines", maybe_limit(%{symbol: sym, interval: int || "1h"}, lim)}
  defp build_req("ticker_24h", sym, _, _, false), do: {"/api/v3/ticker/24hr", %{symbol: sym}}
  defp build_req("ticker_24h", sym, _, _, true), do: {"/fapi/v1/ticker/24hr", %{symbol: sym}}

  defp maybe_limit(p, nil), do: p
  defp maybe_limit(p, lim), do: Map.put(p, :limit, lim)

  defp format("ticker", %{"symbol" => s, "price" => p}), do: {:ok, %{symbol: s, price: p}}
  defp format("depth", %{"bids" => bids, "asks" => asks} = d) do
    {:ok, %{
      last_update_id: d["lastUpdateId"],
      bids: Enum.map(bids, fn [p, q] -> %{price: p, quantity: q} end),
      asks: Enum.map(asks, fn [p, q] -> %{price: p, quantity: q} end)
    }}
  end
  defp format("klines", data) when is_list(data) do
    {:ok, %{klines: Enum.map(data, fn [ot,o,h,l,c,v,ct,qv|_] ->
      %{open_time: ot, open: o, high: h, low: l, close: c, volume: v, close_time: ct, quote_volume: qv}
    end)}}
  end
  defp format("ticker_24h", d) do
    {:ok, %{
      symbol: d["symbol"], price_change: d["priceChange"],
      price_change_percent: d["priceChangePercent"], weighted_avg_price: d["weightedAvgPrice"],
      last_price: d["lastPrice"], volume: d["volume"], quote_volume: d["quoteVolume"],
      open_price: d["openPrice"], high_price: d["highPrice"], low_price: d["lowPrice"]
    }}
  end
  defp format(_, data), do: {:ok, data}
end
