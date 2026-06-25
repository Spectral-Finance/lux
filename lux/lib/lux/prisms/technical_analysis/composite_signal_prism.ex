defmodule Lux.Prisms.TechnicalAnalysis.CompositeSignal do
  @moduledoc """
  A prism that combines multiple technical indicators into a single composite signal.

  Weighs RSI, MACD, Bollinger Bands, and Moving Averages to produce an overall
  trading signal with confidence score.

  ## Examples

      iex> Lux.Prisms.TechnicalAnalysis.CompositeSignal.run(%{
      ...>   rsi: %{rsi: 35, signal: "oversold"},
      ...>   macd: %{crossover: "bullish"},
      ...>   bollinger: %{signal: "below_lower"},
      ...>   sma: %{trend: "uptrend"}
      ...> })
      {:ok, %{signal: "buy", confidence: 0.78, breakdown: %{...}}}
  """

  use Lux.Prism,
    name: "Composite Signal",
    description: "Combines multiple technical indicators into a unified trading signal",
    input_schema: %{
      type: :object,
      properties: %{
        rsi: %{
          type: :object,
          properties: %{
            rsi: %{type: :number},
            signal: %{type: :string, enum: ["overbought", "oversold", "neutral"]}
          }
        },
        macd: %{
          type: :object,
          properties: %{
            macd_line: %{type: :number},
            signal_line: %{type: :number},
            histogram: %{type: :number},
            crossover: %{type: :string, enum: ["bullish", "bearish", "none"]}
          }
        },
        bollinger: %{
          type: :object,
          properties: %{
            pct_b: %{type: :number},
            bandwidth: %{type: :number},
            signal: %{type: :string, enum: ["above_upper", "below_lower", "near_middle", "within_bands"]}
          }
        },
        moving_average: %{
          type: :object,
          properties: %{
            ma_value: %{type: :number},
            trend: %{type: :string, enum: ["uptrend", "downtrend", "neutral"]}
          }
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        signal: %{type: :string, enum: ["strong_buy", "buy", "hold", "sell", "strong_sell"]},
        confidence: %{type: :number, minimum: 0, maximum: 1},
        score: %{type: :number, description: "Composite score -100 to 100"},
        breakdown: %{
          type: :object,
          properties: %{
            rsi_score: %{type: :number},
            macd_score: %{type: :number},
            bollinger_score: %{type: :number},
            ma_score: %{type: :number}
          }
        },
        weights: %{type: :object}
      },
      required: ["signal", "confidence", "score", "breakdown", "weights"]
    }

  @default_weights %{rsi: 0.25, macd: 0.30, bollinger: 0.20, ma: 0.25}

  def handler(input, _ctx) do
    weights = Map.get(input, :weights, @default_weights)

    rsi_score = score_indicator(Map.get(input, :rsi, %{}), weights.rsi)
    macd_score = score_indicator(Map.get(input, :macd, %{}), weights.macd)
    bb_score = score_indicator(Map.get(input, :bollinger, %{}), weights.bollinger)
    ma_score = score_indicator(Map.get(input, :moving_average, %{}), weights.ma)

    total_weight = weights.rsi + weights.macd + weights.bollinger + weights.ma
    composite = (rsi_score + macd_score + bb_score + ma_score) / total_weight

    score = Float.round(composite * 100, 0)
    signal = score_to_signal(score)
    confidence = Float.round(min(abs(composite), 1.0) + 0.1, 2)

    {:ok, %{
      signal: signal,
      confidence: min(confidence, 1.0),
      score: round(score),
      breakdown: %{
        rsi_score: Float.round(rsi_score, 4),
        macd_score: Float.round(macd_score, 4),
        bollinger_score: Float.round(bb_score, 4),
        ma_score: Float.round(ma_score, 4)
      },
      weights: weights
    }}
  end

  defp score_indicator(%{signal: "oversold"} = data, weight) do
    rsi = Map.get(data, :rsi, 50)
    base = if rsi < 20, do: 1.0, else: 0.8
    base * weight
  end

  defp score_indicator(%{signal: "overbought"} = data, weight) do
    rsi = Map.get(data, :rsi, 50)
    base = if rsi > 80, do: -1.0, else: -0.8
    base * weight
  end

  defp score_indicator(%{crossover: "bullish"} = data, weight) do
    hist = Map.get(data, :histogram, 0)
    base = if hist > 0, do: 0.8, else: 0.5
    base * weight
  end

  defp score_indicator(%{crossover: "bearish"} = data, weight) do
    hist = Map.get(data, :histogram, 0)
    base = if hist < 0, do: -0.8, else: -0.5
    base * weight
  end

  defp score_indicator(%{signal: "below_lower"} = _data, weight), do: 0.7 * weight
  defp score_indicator(%{signal: "above_upper"} = _data, weight), do: -0.7 * weight
  defp score_indicator(%{signal: "within_bands"} = _data, weight), do: 0.0

  defp score_indicator(%{trend: "uptrend"} = data, weight) do
    pct = Map.get(data, :pct_b, 0.5)
    base = if pct > 0.5, do: 0.6, else: 0.3
    base * weight
  end

  defp score_indicator(%{trend: "downtrend"} = data, weight) do
    pct = Map.get(data, :pct_b, 0.5)
    base = if pct < 0.5, do: -0.6, else: -0.3
    base * weight
  end

  defp score_indicator(%{trend: "neutral"} = _data, weight), do: 0.0

  defp score_indicator(_data, _weight), do: 0.0

  defp score_to_signal(score) when score >= 60, do: "strong_buy"
  defp score_to_signal(score) when score >= 20, do: "buy"
  defp score_to_signal(score) when score > -20, do: "hold"
  defp score_to_signal(score) when score > -60, do: "sell"
  defp score_to_signal(_score), do: "strong_sell"
end
