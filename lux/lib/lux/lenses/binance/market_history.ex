defmodule Lux.Lenses.Binance.MarketHistory do
  @moduledoc """
  Lens for fetching historical kline/candlestick data from Binance.
  """

  alias Lux.Integrations.Binance.Client

  @valid_intervals ~w(1s 1m 3m 5m 15m 30m 1h 2h 4h 6h 8h 12h 1d 3d 1w 1M)

  def focus(params, _opts \\ []) do
    symbol = params[:symbol] || params["symbol"]
    interval = params[:interval] || params["interval"] || "1h"
    futures = params[:futures] || false
    plug = params[:plug]
    limit = params[:limit]

    path = if futures, do: "/fapi/v1/klines", else: "/api/v3/klines"
    qp = %{symbol: symbol, interval: interval}
    qp = if params[:start_time], do: Map.put(qp, :startTime, params[:start_time]), else: qp
    qp = if params[:end_time], do: Map.put(qp, :endTime, params[:end_time]), else: qp
    qp = if limit, do: Map.put(qp, :limit, limit), else: qp

    opts = %{params: qp, futures: futures}
    opts = if plug, do: Map.put(opts, :plug, plug), else: opts

    case Client.request(:get, path, opts) do
      {:ok, data} when is_list(data) ->
        {:ok, Enum.map(data, &format_kline/1)}
      {:error, e} -> {:error, e}
    end
  end

  def valid_intervals, do: @valid_intervals

  defp format_kline([ot, o, h, l, c, v, ct, qv | _]) do
    %{
      open_time: ot, open: o, high: h, low: l, close: c,
      volume: v, close_time: ct, quote_volume: qv
    }
  end
end
