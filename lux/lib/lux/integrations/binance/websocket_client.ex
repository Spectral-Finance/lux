defmodule Lux.Integrations.Binance.WebsocketClient do
  @moduledoc """
  WebSocket stream URL builder and message parser for Binance Spot and Futures live feeds.
  Supports orderbook depth, trade ticks, aggregate trades, candlesticks (klines), and mark prices.
  """

  @spot_ws_base "wss://stream.binance.com:9443/ws"
  @spot_combined_ws "wss://stream.binance.com:9443/stream"
  @futures_ws_base "wss://fstream.binance.com/ws"
  @futures_combined_ws "wss://fstream.binance.com/stream"

  @doc """
  Constructs single stream WebSocket URL.
  """
  @spec single_stream_url(:spot | :futures, String.t(), String.t()) :: String.t()
  def single_stream_url(market_type, symbol, stream_name) do
    base = if market_type == :spot, do: @spot_ws_base, else: @futures_ws_base
    stream = "#{String.downcase(symbol)}@#{stream_name}"
    "#{base}/#{stream}"
  end

  @doc """
  Constructs combined multiple stream WebSocket URL.
  """
  @spec combined_streams_url(:spot | :futures, list(String.t())) :: String.t()
  def combined_streams_url(market_type, streams) when is_list(streams) do
    base = if market_type == :spot, do: @spot_combined_ws, else: @futures_combined_ws
    stream_params = Enum.map_join(streams, "/", &String.downcase/1)
    "#{base}?streams=#{stream_params}"
  end

  @doc """
  Parses incoming JSON WebSocket event into typed data structures.
  """
  @spec parse_event(map()) :: {:ok, atom(), map()} | {:error, term()}
  def parse_event(%{"e" => "depthUpdate"} = event) do
    {:ok, :orderbook_update,
     %{
       symbol: event["s"],
       first_update_id: event["U"],
       final_update_id: event["u"],
       bids: parse_price_qty(event["b"]),
       asks: parse_price_qty(event["a"]),
       timestamp: event["E"]
     }}
  end

  def parse_event(%{"e" => "trade"} = event) do
    {:ok, :trade,
     %{
       symbol: event["s"],
       trade_id: event["t"],
       price: parse_float(event["p"]),
       quantity: parse_float(event["q"]),
       buyer_is_maker: event["m"],
       timestamp: event["T"]
     }}
  end

  def parse_event(%{"e" => "kline"} = event) do
    k = event["k"]
    {:ok, :kline,
     %{
       symbol: event["s"],
       interval: k["i"],
       open: parse_float(k["o"]),
       high: parse_float(k["h"]),
       low: parse_float(k["l"]),
       close: parse_float(k["c"]),
       volume: parse_float(k["v"]),
       closed?: k["x"],
       timestamp: event["E"]
     }}
  end

  def parse_event(%{"e" => "markPriceUpdate"} = event) do
    {:ok, :mark_price,
     %{
       symbol: event["s"],
       mark_price: parse_float(event["p"]),
       index_price: parse_float(event["i"]),
       estimated_settle_price: parse_float(event["P"]),
       funding_rate: parse_float(event["r"]),
       timestamp: event["E"]
     }}
  end

  def parse_event(%{"stream" => _stream, "data" => data}) do
    parse_event(data)
  end

  def parse_event(other), do: {:ok, :generic, other}

  defp parse_price_qty(entries) when is_list(entries) do
    Enum.map(entries, fn [p, q] ->
      {parse_float(p), parse_float(q)}
    end)
  end

  defp parse_price_qty(_), do: []

  defp parse_float(val) when is_float(val), do: val
  defp parse_float(val) when is_integer(val), do: val * 1.0
  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 0.0
    end
  end
  defp parse_float(_), do: 0.0
end
