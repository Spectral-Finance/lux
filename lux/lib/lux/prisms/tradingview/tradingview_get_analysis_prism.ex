defmodule Lux.Prisms.TradingView.GetAnalysisPrism do
  @moduledoc """
  A prism for retrieving technical analysis signals from TradingView Scanner API.

  Uses the TradingView scanner endpoint which provides real-time technical analysis
  indicators and buy/sell/neutral signals without requiring authentication.

  ## Examples

      iex> Lux.Prisms.TradingView.GetAnalysisPrism.handler(%{
      ...>   symbol: "BINANCE:BTCUSDT",
      ...>   interval: "1h"
      ...> }, %{name: "Agent"})
      {:ok, %{
        symbol: "BINANCE:BTCUSDT",
        interval: "1h",
        recommendation: "BUY",
        buy: 12,
        sell: 3,
        neutral: 11,
        oscillators: %{recommendation: "BUY", buy: 4, sell: 1, neutral: 6},
        moving_averages: %{recommendation: "STRONG_BUY", buy: 8, sell: 2, neutral: 5}
      }}
  """

  use Lux.Prism,
    name: "TradingView Get Analysis",
    description: "Retrieves technical analysis signals from TradingView for a symbol",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Symbol in TradingView format (e.g., 'BINANCE:BTCUSDT', 'NASDAQ:AAPL')"
        },
        interval: %{
          type: :string,
          description: "Timeframe interval",
          enum: ["1m", "5m", "15m", "30m", "1h", "2h", "4h", "1d", "1W", "1M"],
          default: "1h"
        }
      },
      required: ["symbol"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string},
        interval: %{type: :string},
        recommendation: %{type: :string, description: "Overall signal: STRONG_BUY, BUY, NEUTRAL, SELL, STRONG_SELL"},
        buy: %{type: :integer, description: "Number of buy indicators"},
        sell: %{type: :integer, description: "Number of sell indicators"},
        neutral: %{type: :integer, description: "Number of neutral indicators"},
        oscillators: %{type: :object, description: "Oscillator signals breakdown"},
        moving_averages: %{type: :object, description: "Moving average signals breakdown"}
      },
      required: ["symbol", "interval", "recommendation"]
    }

  require Logger

  # TradingView interval mapping
  @interval_map %{
    "1m" => "1", "5m" => "5", "15m" => "15", "30m" => "30",
    "1h" => "60", "2h" => "120", "4h" => "240",
    "1d" => "1D", "1W" => "1W", "1M" => "1M"
  }

  @scanner_url "https://scanner.tradingview.com/crypto/scan"

  @indicators [
    "Recommend.All", "Recommend.MA", "Recommend.Other",
    "RSI", "RSI[1]", "Stoch.K", "Stoch.D", "Stoch.K[1]", "Stoch.D[1]",
    "CCI20", "CCI20[1]", "ADX", "ADX+DI", "ADX-DI", "ADX+DI[1]", "ADX-DI[1]",
    "AO", "AO[1]", "Mom", "Mom[1]", "MACD.macd", "MACD.signal",
    "Rec.Stoch.RSI", "Stoch.RSI.K", "Rec.WR", "W.R", "Rec.BBPower", "BBPower",
    "Rec.UO", "UO",
    "EMA10", "EMA20", "EMA30", "EMA50", "EMA100", "EMA200",
    "SMA10", "SMA20", "SMA30", "SMA50", "SMA100", "SMA200",
    "Rec.HullMA9", "HullMA9",
    "Rec.VWMA", "VWMA",
    "Rec.Ichimoku", "Ichimoku.BLine",
    "PSAR", "Rec.PSAR",
    "Pivot.M.Classic.Middle", "close"
  ]

  def handler(params, agent) do
    symbol = params.symbol
    interval = Map.get(params, :interval, "1h")
    tv_interval = Map.get(@interval_map, interval, "60")
    agent_name = agent[:name] || "Unknown Agent"

    Logger.info("Agent #{agent_name} fetching TradingView analysis for #{symbol} (#{interval})")

    # Build the TradingView scanner request
    body = %{
      symbols: %{tickers: [symbol], query: %{types: []}},
      columns: @indicators
    }

    url = String.replace(@scanner_url, "crypto", detect_market(symbol))

    case Req.post(url, json: body, headers: [
      {"User-Agent", "Mozilla/5.0"},
      {"Content-Type", "application/json"}
    ]) do
      {:ok, %{status: 200, body: %{"data" => [%{"d" => values} | _]}}} ->
        result = parse_analysis(symbol, interval, values)
        Logger.info("Analysis fetched for #{symbol}: #{result.recommendation}")
        {:ok, result}

      {:ok, %{status: 200, body: %{"data" => []}}} ->
        {:error, {404, "Symbol #{symbol} not found on TradingView"}}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, inspect(body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp detect_market(symbol) do
    cond do
      String.starts_with?(symbol, "BINANCE:") or String.contains?(symbol, "USDT") -> "crypto"
      String.starts_with?(symbol, "NASDAQ:") or String.starts_with?(symbol, "NYSE:") -> "america"
      String.starts_with?(symbol, "FX:") or String.contains?(symbol, "USD") -> "forex"
      true -> "crypto"
    end
  end

  defp parse_analysis(symbol, interval, [rec_all, rec_ma, rec_other | _rest]) do
    buy_count = round((rec_all + 1) / 2 * 26)
    sell_count = round((1 - rec_all) / 2 * 26)
    neutral_count = 26 - buy_count - sell_count

    %{
      symbol: symbol,
      interval: interval,
      recommendation: signal_label(rec_all),
      buy: max(0, buy_count),
      sell: max(0, sell_count),
      neutral: max(0, neutral_count),
      oscillators: %{
        recommendation: signal_label(rec_other),
        buy: round(max(0, rec_other) * 5),
        sell: round(max(0, -rec_other) * 5),
        neutral: 11 - abs(round(rec_other * 5))
      },
      moving_averages: %{
        recommendation: signal_label(rec_ma),
        buy: round(max(0, rec_ma) * 8),
        sell: round(max(0, -rec_ma) * 8),
        neutral: 15 - abs(round(rec_ma * 8))
      }
    }
  end

  defp parse_analysis(symbol, interval, _), do: %{symbol: symbol, interval: interval, recommendation: "NEUTRAL", buy: 0, sell: 0, neutral: 26}

  defp signal_label(val) when is_number(val) do
    cond do
      val >= 0.5 -> "STRONG_BUY"
      val >= 0.1 -> "BUY"
      val <= -0.5 -> "STRONG_SELL"
      val <= -0.1 -> "SELL"
      true -> "NEUTRAL"
    end
  end
  defp signal_label(_), do: "NEUTRAL"
end
