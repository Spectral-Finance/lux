defmodule Lux.Integrations.TradingView do
  @moduledoc """
  Base configuration module for TradingView integration.

  Provides constants, endpoint URLs, interval mappings, and screener definitions
  for interacting with TradingView's technical analysis scanner API.

  ## Supported Screeners

  TradingView organizes symbols by screener (market region):
  - `america` - US stocks (NASDAQ, NYSE, etc.)
  - `crypto` - Cryptocurrency exchanges
  - `forex` - Forex pairs
  - `cfd` - CFD instruments
  - And many more regional screeners

  ## Supported Intervals

  - `1m`, `5m`, `15m`, `30m` - Minute intervals
  - `1h`, `2h`, `4h` - Hour intervals
  - `1d` - Daily (default)
  - `1W` - Weekly
  - `1M` - Monthly
  """

  @scanner_base_url "https://scanner.tradingview.com"

  @intervals %{
    "1m" => "1",
    "5m" => "5",
    "15m" => "15",
    "30m" => "30",
    "1h" => "60",
    "2h" => "120",
    "4h" => "240",
    "1d" => "",
    "1W" => "1W",
    "1M" => "1M"
  }

  @screeners [
    "america",
    "australia",
    "brazil",
    "cfd",
    "crypto",
    "euronext",
    "forex",
    "germany",
    "hongkong",
    "india",
    "indonesia",
    "japan",
    "korea",
    "malaysia",
    "philippines",
    "russia",
    "singapore",
    "spain",
    "sweden",
    "taiwan",
    "thailand",
    "turkey",
    "uk",
    "vietnam"
  ]

  @recommendation_columns [
    "Recommend.All",
    "Recommend.MA",
    "Recommend.Other"
  ]

  @oscillator_columns [
    "RSI",
    "RSI[1]",
    "Stoch.K",
    "Stoch.D",
    "Stoch.K[1]",
    "Stoch.D[1]",
    "CCI20",
    "CCI20[1]",
    "ADX",
    "ADX+DI",
    "ADX-DI",
    "ADX+DI[1]",
    "ADX-DI[1]",
    "AO",
    "AO[1]",
    "AO[2]",
    "Mom",
    "Mom[1]",
    "MACD.macd",
    "MACD.signal",
    "W.R",
    "BBPower",
    "UO"
  ]

  @moving_average_columns [
    "EMA10",
    "SMA10",
    "EMA20",
    "SMA20",
    "EMA30",
    "SMA30",
    "EMA50",
    "SMA50",
    "EMA100",
    "SMA100",
    "EMA200",
    "SMA200",
    "Ichimoku.BLine",
    "VWMA",
    "HullMA9"
  ]

  @price_columns [
    "close",
    "open",
    "high",
    "low",
    "volume",
    "change",
    "change_abs"
  ]

  @pivot_columns [
    "Pivot.M.Classic.S3",
    "Pivot.M.Classic.S2",
    "Pivot.M.Classic.S1",
    "Pivot.M.Classic.Middle",
    "Pivot.M.Classic.R1",
    "Pivot.M.Classic.R2",
    "Pivot.M.Classic.R3"
  ]

  @doc "Returns the TradingView scanner base URL."
  @spec scanner_base_url() :: String.t()
  def scanner_base_url, do: @scanner_base_url

  @doc "Returns the scanner endpoint URL for a given screener."
  @spec scanner_url(String.t()) :: String.t()
  def scanner_url(screener) when screener in @screeners do
    "#{@scanner_base_url}/#{screener}/scan"
  end

  def scanner_url(screener) do
    raise ArgumentError, "Invalid screener: #{screener}. Must be one of: #{Enum.join(@screeners, ", ")}"
  end

  @doc "Returns the interval suffix for TradingView column names."
  @spec interval_suffix(String.t()) :: String.t()
  def interval_suffix(interval) when is_map_key(@intervals, interval) do
    case @intervals[interval] do
      "" -> ""
      suffix -> "|#{suffix}"
    end
  end

  def interval_suffix(interval) do
    raise ArgumentError, "Invalid interval: #{interval}. Must be one of: #{Enum.join(Map.keys(@intervals), ", ")}"
  end

  @doc "Appends the interval suffix to a column name."
  @spec column_with_interval(String.t(), String.t()) :: String.t()
  def column_with_interval(column, interval) do
    "#{column}#{interval_suffix(interval)}"
  end

  @doc "Returns the list of supported intervals."
  @spec intervals() :: [String.t()]
  def intervals, do: Map.keys(@intervals)

  @doc "Returns the list of supported screeners."
  @spec screeners() :: [String.t()]
  def screeners, do: @screeners

  @doc "Returns recommendation column names."
  @spec recommendation_columns() :: [String.t()]
  def recommendation_columns, do: @recommendation_columns

  @doc "Returns oscillator indicator column names."
  @spec oscillator_columns() :: [String.t()]
  def oscillator_columns, do: @oscillator_columns

  @doc "Returns moving average column names."
  @spec moving_average_columns() :: [String.t()]
  def moving_average_columns, do: @moving_average_columns

  @doc "Returns price data column names."
  @spec price_columns() :: [String.t()]
  def price_columns, do: @price_columns

  @doc "Returns pivot point column names."
  @spec pivot_columns() :: [String.t()]
  def pivot_columns, do: @pivot_columns

  @doc "Returns all available column names."
  @spec all_columns() :: [String.t()]
  def all_columns do
    @recommendation_columns ++
      @oscillator_columns ++
      @moving_average_columns ++
      @price_columns ++
      @pivot_columns
  end

  @doc "Returns the default HTTP headers for TradingView API requests."
  @spec headers() :: [{String.t(), String.t()}]
  def headers do
    [
      {"content-type", "application/json"},
      {"user-agent", "Lux/#{Application.spec(:lux, :vsn) || "0.5.0"}"}
    ]
  end

  @doc """
  Formats a ticker symbol in TradingView format.

  ## Examples

      iex> Lux.Integrations.TradingView.format_ticker("TSLA", "NASDAQ")
      "NASDAQ:TSLA"

      iex> Lux.Integrations.TradingView.format_ticker("BTCUSD", "BINANCE")
      "BINANCE:BTCUSD"
  """
  @spec format_ticker(String.t(), String.t()) :: String.t()
  def format_ticker(symbol, exchange) do
    "#{String.upcase(exchange)}:#{String.upcase(symbol)}"
  end

  @doc """
  Classifies a recommendation value into a human-readable string.

  TradingView recommendation values range from -1 to 1:
  - Strong Sell: value <= -0.5
  - Sell: -0.5 < value <= -0.1
  - Neutral: -0.1 < value < 0.1
  - Buy: 0.1 <= value < 0.5
  - Strong Buy: value >= 0.5

  ## Examples

      iex> Lux.Integrations.TradingView.classify_recommendation(0.7)
      "STRONG_BUY"

      iex> Lux.Integrations.TradingView.classify_recommendation(-0.3)
      "SELL"
  """
  @spec classify_recommendation(number()) :: String.t()
  def classify_recommendation(value) when is_number(value) do
    cond do
      value >= 0.5 -> "STRONG_BUY"
      value >= 0.1 -> "BUY"
      value > -0.1 -> "NEUTRAL"
      value > -0.5 -> "SELL"
      true -> "STRONG_SELL"
    end
  end

  def classify_recommendation(nil), do: "NEUTRAL"
end
