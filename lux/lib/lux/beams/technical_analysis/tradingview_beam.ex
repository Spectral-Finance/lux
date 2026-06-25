defmodule Lux.Beams.TechnicalAnalysis.TradingViewBeam do
  @moduledoc """
  Orchestrates a complete technical analysis workflow using TradingView data
  and multiple technical indicators.

  This beam:
  1. Fetches chart data (candlesticks) for the given symbol
  2. Runs multiple technical indicators in parallel (RSI, MACD, Bollinger Bands, Moving Averages)
  3. Performs multi-timeframe analysis if additional data is provided
  4. Generates alerts based on indicator thresholds
  5. Produces a composite trading signal

  ## Example

      alias Lux.Beams.TechnicalAnalysis.TradingViewBeam

      TradingViewBeam.run(%{
        symbol: "BINANCE:BTCUSDT",
        interval: "D",
        from: 1700000000,
        to: 1700604800,
        rsi_period: 14,
        macd: %{fast_period: 12, slow_period: 26, signal_period: 9},
        bollinger: %{period: 20, std_dev: 2},
        alert_thresholds: %{rsi_overbought: 70, rsi_oversold: 30}
      })
  """

  use Lux.Beam,
    name: "TradingView Technical Analysis",
    description: "Complete technical analysis workflow with TradingView data and multiple indicators",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "TradingView symbol"},
        interval: %{type: :string, description: "Candle interval"},
        from: %{type: :integer, description: "Start timestamp"},
        to: %{type: :integer, description: "End timestamp"},
        rsi_period: %{type: :integer, default: 14},
        macd: %{
          type: :object,
          properties: %{
            fast_period: %{type: :integer, default: 12},
            slow_period: %{type: :integer, default: 26},
            signal_period: %{type: :integer, default: 9}
          }
        },
        bollinger: %{
          type: :object,
          properties: %{
            period: %{type: :integer, default: 20},
            std_dev: %{type: :number, default: 2}
          }
        },
        alert_thresholds: %{
          type: :object,
          properties: %{
            rsi_overbought: %{type: :number, default: 70},
            rsi_oversold: %{type: :number, default: 30}
          }
        }
      },
      required: ["symbol", "interval", "from", "to"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string},
        timeframe: %{type: :string},
        signal: %{type: :string},
        confidence: %{type: :number},
        indicators: %{type: :object},
        alerts: %{type: :array},
        timestamp: %{type: :string}
      }
    },
    generate_execution_log: true

  alias Lux.Lenses.TradingView.ChartDataLens
  alias Lux.Lenses.TradingView.QuoteLens
  alias Lux.Prisms.TechnicalAnalysis.RSI
  alias Lux.Prisms.TechnicalAnalysis.MACD
  alias Lux.Prisms.TechnicalAnalysis.BollingerBands
  alias Lux.Prisms.TechnicalAnalysis.MovingAverage
  alias Lux.Prisms.TechnicalAnalysis.AlertManager
  alias Lux.Prisms.TechnicalAnalysis.CompositeSignal

  sequence do
    # Step 1: Fetch chart data
    step(:chart_data, ChartDataLens, %{
      symbol: :symbol,
      interval: :interval,
      from: :from,
      to: :to
    })

    # Step 2: Fetch real-time quote
    step(:quote, QuoteLens, %{
      symbols: [{:ref, "chart_data.symbol"} | []],
      screen: "crypto"
    }, fallback: fn _ -> {:continue, %{quote: nil}} end)

    # Step 3: Run technical indicators in parallel
    parallel do
      step(:rsi, RSI, %{
        prices: {:ref, "chart_data.closes"},
        period: {:ref, "rsi_period", 14}
      }, store_io: true)

      step(:macd, MACD, %{
        prices: {:ref, "chart_data.closes"},
        fast_period: {:ref, "macd.fast_period", 12},
        slow_period: {:ref, "macd.slow_period", 26},
        signal_period: {:ref, "macd.signal_period", 9}
      }, store_io: true)

      step(:bollinger, BollingerBands, %{
        prices: {:ref, "chart_data.closes"},
        period: {:ref, "bollinger.period", 20},
        std_dev: {:ref, "bollinger.std_dev", 2}
      }, store_io: true)

      step(:moving_average, MovingAverage, %{
        prices: {:ref, "chart_data.closes"},
        type: "sma",
        period: {:ref, "bollinger.period", 20}
      }, store_io: true)
    end

    # Step 4: Generate alerts
    step(:alerts, AlertManager, %{
      indicators: %{
        rsi: {:ref, "rsi.rsi"},
        macd_histogram: {:ref, "macd.histogram"},
        bb_pct_b: {:ref, "bollinger.pct_b"}
      },
      alerts: [{:ref, "alert_thresholds"}]
    })

    # Step 5: Produce composite signal
    step(:composite, CompositeSignal, %{
      rsi: %{
        rsi: {:ref, "rsi.rsi"},
        signal: {:ref, "rsi.signal"}
      },
      macd: %{
        crossover: {:ref, "macd.crossover"},
        histogram: {:ref, "macd.histogram"}
      },
      bollinger: %{
        signal: {:ref, "bollinger.signal"},
        pct_b: {:ref, "bollinger.pct_b"}
      },
      moving_average: %{
        trend: {:ref, "moving_average.trend"}
      }
    })
  end

  @doc """
  Custom run function that transforms the raw beam output into a clean signal.
  """
  def run(input, opts \ []) do
    case TradingViewBeam.view() |> Lux.Beam.Runner.run(input, opts) do
      {:ok, result, log} ->
        transformed = transform_output(result, input)
        {:ok, transformed, log}

      error ->
        error
    end
  end

  defp transform_output(%{composite: composite} = result, input) do
    %{
      symbol: input.symbol,
      timeframe: input.interval,
      signal: composite.signal,
      confidence: composite.confidence,
      score: composite.score,
      indicators: %{
        rsi: Map.get(result, :rsi, %{}),
        macd: Map.get(result, :macd, %{}),
        bollinger: Map.get(result, :bollinger, %{}),
        moving_average: Map.get(result, :moving_average, %{})
      },
      alerts: Map.get(result, :alerts, %{}),
      quote: Map.get(result, :quote, %{}),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp transform_output(result, _input) do
    %{
      signal: "hold",
      confidence: 0.0,
      indicators: %{},
      alerts: %{},
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      raw_output: result
    }
  end
end
