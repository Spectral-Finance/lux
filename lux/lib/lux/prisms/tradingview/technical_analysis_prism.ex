defmodule Lux.Prisms.TradingView.TechnicalAnalysisPrism do
  @moduledoc """
  A prism that performs technical analysis on cryptocurrency price data.

  Calculates key technical indicators (RSI, MACD, Bollinger Bands, SMA, EMA)
  and generates trading signals using Python-based analysis engine.

  ## Example

      iex> Lux.Prisms.TradingView.TechnicalAnalysisPrism.run(%{
      ...>   symbol: "BTCUSDT",
      ...>   interval: "1h",
      ...>   period: 100
      ...> })
      {:ok, %{
        symbol: "BTCUSDT",
        current_price: 67500.0,
        indicators: %{
          rsi: %{latest: 52.3, values: [...]},
          macd: %{macd: [...], signal: [...], histogram: [...]},
          bollinger_bands: %{upper: [...], middle: [...], lower: [...]},
          sma_20: 67200.0,
          sma_50: 66800.0
        },
        signals: %{
          consensus: "buy",
          strength: 65,
          individual_signals: %{...},
          reasoning: [...]
        }
      }}

  The prism uses the Binance public API for price data (no API key required)
  and performs all calculations locally using Python.
  """

  use Lux.Prism,
    name: "TradingView Technical Analysis",
    description: "Performs technical analysis with RSI, MACD, Bollinger Bands, and Moving Averages",
    examples: [
      "Run analysis on BTC/USDT with hourly candles",
      "Analyze ETH/USDT daily chart for trend signals",
      "Get trading signals for multiple symbols"
    ],
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol (e.g., BTCUSDT, ETHUSDT)",
          default: "BTCUSDT"
        },
        interval: %{
          type: :string,
          description: "Candle interval",
          enum: ["1m", "5m", "15m", "30m", "1h", "4h", "1d"],
          default: "1h"
        },
        period: %{
          type: :integer,
          description: "Number of candles for analysis",
          default: 100,
          minimum: 50,
          maximum: 1000
        }
      },
      required: ["symbol"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string},
        interval: %{type: :string},
        current_price: %{type: :number},
        indicators: %{
          type: :object,
          properties: %{
            rsi: %{
              type: :object,
              properties: %{
                latest: %{type: :number},
                signal: %{type: :string}
              }
            },
            macd: %{
              type: :object,
              properties: %{
                macd_line: %{type: :number},
                signal_line: %{type: :number},
                histogram: %{type: :number},
                signal: %{type: :string}
              }
            },
            bollinger_bands: %{
              type: :object,
              properties: %{
                upper: %{type: :number},
                middle: %{type: :number},
                lower: %{type: :number},
                position: %{type: :number}
              }
            },
            sma_20: %{type: :number},
            sma_50: %{type: :number},
            ema_12: %{type: :number},
            ema_26: %{type: :number}
          }
        },
        signals: %{
          type: :object,
          properties: %{
            consensus: %{type: :string},
            strength: %{type: :integer},
            reasoning: %{type: :array, items: %{type: :string}}
          }
        }
      },
      required: ["symbol", "indicators", "signals"]
    }

  import Lux.Python

  require Logger

  @doc """
  Executes technical analysis on the given symbol.
  """
  def handler(input, _ctx) do
    symbol = Map.get(input, "symbol", Map.get(input, :symbol, "BTCUSDT"))
    interval = Map.get(input, "interval", Map.get(input, :interval, "1h"))
    period = Map.get(input, "period", Map.get(input, :period, 100))

    with {:ok, price_data} <- fetch_price_data(symbol, interval, period),
         {:ok, analysis} <- calculate_indicators(price_data, symbol, interval) do
      {:ok, format_output(analysis)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_price_data(symbol, interval, period) do
    python_result =
      python variables: %{symbol: symbol, interval: interval, period: period} do
        ~PY"""
        from tradingview.price_fetcher import PriceFetcher

        fetcher = PriceFetcher()
        klines = fetcher.get_klines(symbol, interval, period)

        if not klines:
            {"error": f"No price data available for {symbol}"}
        else:
            klines
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_list(result) -> {:ok, result}
      _ -> {:error, "Unexpected price data format"}
    end
  end

  defp calculate_indicators(price_data, symbol, interval) do
    python_result =
      python variables: %{
        price_data: price_data,
        symbol: symbol,
        interval: interval
      } do
        ~PY"""
        from tradingview import TechnicalAnalyzer

        analyzer = TechnicalAnalyzer()

        # Extract OHLCV data
        closes = [float(k["close"]) for k in price_data]
        highs = [float(k["high"]) for k in price_data]
        lows = [float(k["low"]) for k in price_data]

        # Calculate indicators
        from tradingview.indicators import Indicators
        ind = Indicators()

        rsi_values = ind.rsi(closes)
        macd_data = ind.macd(closes)
        bb_data = ind.bollinger_bands(closes)
        sma_20 = ind.sma(closes, 20)
        sma_50 = ind.sma(closes, 50)
        ema_12 = ind.ema(closes, 12)
        ema_26 = ind.ema(closes, 26)

        # Generate signals
        from tradingview.signal_generator import SignalGenerator
        gen = SignalGenerator()

        signals = gen.generate_signals(closes, rsi_values, macd_data, bb_data, sma_20, sma_50)

        # Get latest values
        latest_rsi = next((v for v in reversed(rsi_values) if v is not None), None)
        latest_macd = macd_data["macd"][-1] if macd_data["macd"][-1] is not None else 0
        latest_signal = macd_data["signal"][-1] if macd_data["signal"][-1] is not None else 0
        latest_hist = macd_data["histogram"][-1] if macd_data["histogram"][-1] is not None else 0
        latest_bb_upper = bb_data["upper"][-1] if bb_data["upper"][-1] is not None else 0
        latest_bb_middle = bb_data["middle"][-1] if bb_data["middle"][-1] is not None else 0
        latest_bb_lower = bb_data["lower"][-1] if bb_data["lower"][-1] is not None else 0

        result = {
            "symbol": symbol,
            "interval": interval,
            "current_price": closes[-1],
            "indicators": {
                "rsi": {
                    "latest": latest_rsi,
                    "values": [v for v in rsi_values if v is not None][-10:]
                },
                "macd": {
                    "macd_line": latest_macd,
                    "signal_line": latest_signal,
                    "histogram": latest_hist
                },
                "bollinger_bands": {
                    "upper": latest_bb_upper,
                    "middle": latest_bb_middle,
                    "lower": latest_bb_lower
                },
                "sma_20": sma_20[-1] if sma_20[-1] is not None else None,
                "sma_50": sma_50[-1] if sma_50[-1] is not None else None,
                "ema_12": ema_12[-1] if ema_12[-1] is not None else None,
                "ema_26": ema_26[-1] if ema_26[-1] is not None else None
            },
            "signals": signals
        }

        result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
      _ -> {:error, "Unexpected analysis result format"}
    end
  end

  defp format_output(analysis) do
    %{
      symbol: analysis["symbol"],
      interval: analysis["interval"],
      current_price: analysis["current_price"],
      indicators: %{
        rsi: format_rsi(analysis["indicators"]["rsi"]),
        macd: format_macd(analysis["indicators"]["macd"]),
        bollinger_bands: format_bollinger(analysis["indicators"]["bollinger_bands"]),
        sma_20: analysis["indicators"]["sma_20"],
        sma_50: analysis["indicators"]["sma_50"],
        ema_12: analysis["indicators"]["ema_12"],
        ema_26: analysis["indicators"]["ema_26"]
      },
      signals: format_signals(analysis["signals"])
    }
  end

  defp format_rsi(rsi) do
    %{
      latest: rsi["latest"],
      signal: rsi_signal(rsi["latest"])
    }
  end

  defp rsi_signal(nil), do: "neutral"
  defp rsi_signal(rsi) when rsi <= 30, do: "buy"
  defp rsi_signal(rsi) when rsi >= 70, do: "sell"
  defp rsi_signal(_), do: "neutral"

  defp format_macd(macd) do
    %{
      macd_line: macd["macd_line"],
      signal_line: macd["signal_line"],
      histogram: macd["histogram"],
      signal: macd_signal(macd["histogram"])
    }
  end

  defp macd_signal(nil), do: "neutral"
  defp macd_signal(hist) when hist > 0, do: "buy"
  defp macd_signal(hist) when hist < 0, do: "sell"
  defp macd_signal(_), do: "neutral"

  defp format_bollinger(bb) do
    %{
      upper: bb["upper"],
      middle: bb["middle"],
      lower: bb["lower"],
      position: bb_position(bb)
    }
  end

  defp bb_position(%{"upper" => upper, "middle" => _, "lower" => lower})
       when is_number(upper) and is_number(lower) and upper > lower do
    # Position is relative to band width (0 = lower, 0.5 = middle, 1 = upper)
    # We don't have current price here, so return band width info
    (upper - lower) / lower * 100
  end

  defp bb_position(_), do: 0

  defp format_signals(signals) do
    %{
      consensus: signals["consensus"],
      strength: signals["strength"],
      reasoning: signals["reasoning"] || []
    }
  end
end
