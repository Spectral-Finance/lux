defmodule Lux.Integrations.TradingView do
  @moduledoc """
  Configuration for TradingView integration.

  Provides real-time market data streaming and technical analysis capabilities.
  """

  @doc "Get the TradingView WebSocket endpoint."
  def ws_endpoint, do: "wss://data.tradingview.com/socket.io/websocket"

  @doc "Supported exchanges."
  def exchanges do
    ~w(BINANCE COINBASE KRAKEN BITFINEX NYSE NASDAQ AMEX)
  end

  @doc "Supported timeframes for chart data."
  def timeframes do
    %{
      "1" => "1 minute",
      "5" => "5 minutes",
      "15" => "15 minutes",
      "30" => "30 minutes",
      "60" => "1 hour",
      "240" => "4 hours",
      "D" => "1 day",
      "W" => "1 week",
      "M" => "1 month"
    }
  end
end
