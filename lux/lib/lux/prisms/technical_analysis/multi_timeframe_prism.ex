defmodule Lux.Prisms.TechnicalAnalysis.MultiTimeframe do
  @moduledoc """
  A prism that performs multi-timeframe analysis across different intervals.

  Compares technical signals across multiple timeframes to identify
  confluence and divergence patterns. Higher timeframe determines trend bias.

  ## Examples

      iex> Lux.Prisms.TechnicalAnalysis.MultiTimeframe.run(%{
      ...>   timeframes: %{
      ...>     "1D" => %{rsi: 65, trend: "uptrend", macd: "bullish"},
      ...>     "4H" => %{rsi: 55, trend: "neutral", macd: "none"},
      ...>     "1H" => %{rsi: 35, trend: "downtrend", macd: "bearish"}
      ...>   }
      ...> })
      {:ok, %{confluence: "moderate", recommendation: "cautious_buy"}}
  """

  use Lux.Prism,
    name: "Multi-Timeframe Analysis",
    description: "Analyzes signals across multiple timeframes for confluence detection",
    input_schema: %{
      type: :object,
      properties: %{
        timeframes: %{
          type: :object,
          description: "Map of timeframe -> indicator set",
          additionalProperties: %{
            type: :object,
            properties: %{
              rsi: %{type: :number},
              trend: %{type: :string, enum: ["uptrend", "downtrend", "neutral"]},
              macd: %{type: :string, enum: ["bullish", "bearish", "none"]},
              bollinger: %{type: :string, enum: ["above_upper", "below_lower", "within_bands", "near_middle"]}
            }
          }
        }
      },
      required: ["timeframes"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        timeframe_signals: %{type: :object},
        dominant_trend: %{type: :string},
        confluence: %{type: :string, enum: ["strong", "moderate", "weak", "divergent"]},
        recommendation: %{type: :string},
        confidence: %{type: :number}
      },
      required: ["timeframe_signals", "dominant_trend", "confluence", "recommendation", "confidence"]
    }

  @timeframe_priority ["1M", "1W", "1D", "4H", "2H", "1H", "30m", "15m", "5m", "1m"]

  def handler(%{timeframes: timeframes}, _ctx) when is_map(timeframes) and map_size(timeframes) > 0 do
    analyzed =
      timeframes
      |> Enum.sort_by(fn {tf, _} -> Enum.find_index(@timeframe_priority, &String.equivalent?(&1, tf)) end, :asc)
      |> Enum.map(fn {tf, data} ->
        {tf, analyze_single_tf(tf, data)}
      end)
      |> Enum.into(%{})

    dominant = find_dominant_trend(analyzed)
    confluence = assess_confluence(analyzed)
    {recommendation, confidence} = generate_recommendation(dominant, confluence, analyzed)

    {:ok, %{
      timeframe_signals: analyzed,
      dominant_trend: dominant,
      confluence: confluence,
      recommendation: recommendation,
      confidence: Float.round(confidence, 2)
    }}
  end

  def handler(input, _ctx) do
    {:error, "invalid input: #{inspect(input)}"}
  end

  defp analyze_single_tf(tf, data) do
    rsi = Map.get(data, :rsi, 50)
    trend = Map.get(data, :trend, "neutral")
    macd = Map.get(data, :macd, "none")
    bollinger = Map.get(data, :bollinger, "within_bands")

    bullish_count =
      Enum.count([
        rsi < 40,
        trend == "uptrend",
        macd == "bullish",
        bollinger == "below_lower"
      ])

    bearish_count =
      Enum.count([
        rsi > 60,
        trend == "downtrend",
        macd == "bearish",
        bollinger == "above_upper"
      ])

    cond do
      bullish_count > bearish_count + 1 -> %{tf: tf, bias: "bullish", score: bullish_count}
      bearish_count > bullish_count + 1 -> %{tf: tf, bias: "bearish", score: bearish_count}
      true -> %{tf: tf, bias: "neutral", score: max(bullish_count, bearish_count)}
    end
  end

  defp find_dominant_trend(analyzed) do
    analyzed
    |> Enum.filter(fn {_tf, data} -> data.bias in ["bullish", "bearish"] end)
    |> Enum.reduce(%{bullish: 0, bearish: 0}, fn {_tf, data}, acc ->
      Map.put(acc, data.bias, acc[data.bias] + 1)
    end)
    |> then(fn %{bullish: b, bearish: br} ->
      cond do
        b > br -> "bullish"
        br > b -> "bearish"
        true -> "neutral"
      end
    end)
  end

  defp assess_confluence(analyzed) do
    biases = Map.values(analyzed) |> Enum.map(& &1.bias)

    bullish = Enum.count(biases, & &1 == "bullish")
    bearish = Enum.count(biases, & &1 == "bearish")
    total = length(biases)

    cond do
      bullish == total or bearish == total -> "strong"
      bullish >= div(total, 2) + 1 or bearish >= div(total, 2) + 1 -> "moderate"
      bullish + bearish > 0 -> "weak"
      true -> "divergent"
    end
  end

  defp generate_recommendation(dominant, confluence, analyzed) do
    case {dominant, confluence} do
      {"bullish", "strong"} -> {"strong_buy", 0.9}
      {"bullish", "moderate"} -> {"buy", 0.7}
      {"bullish", "weak"} -> {"cautious_buy", 0.5}
      {"bearish", "strong"} -> {"strong_sell", 0.9}
      {"bearish", "moderate"} -> {"sell", 0.7}
      {"bearish", "weak"} -> {"cautious_sell", 0.5}
      {"neutral", _} -> {"hold", 0.3}
      _ -> {"hold", 0.3}
    end
  end
end
