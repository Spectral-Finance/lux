defmodule Lux.Prisms.TradingView.TechnicalAnalysis do
  @moduledoc """
  Prism for performing comprehensive multi-timeframe technical analysis
  using TradingView data.

  Combines technical ratings across multiple timeframes to generate
  weighted trading signals with confidence scores.

  ## Strategies
  - `comprehensive` — Balanced analysis (default)
  - `trend_following` — Boosts when higher timeframes agree
  - `mean_reversion` — Reverses at extremes
  - `momentum` — Focuses on oscillator strength

  ## Examples

      iex> TechnicalAnalysis.handler(%{
      ...>   "symbol" => "BINANCE:BTCUSDT",
      ...>   "timeframes" => ["15", "60", "240", "D"]
      ...> }, nil)
      {:ok, %{symbol: "BINANCE:BTCUSDT", signal: :buy, confidence: 0.72, ...}}
  """

  use Lux.Prism,
    name: "TradingView Technical Analysis",
    description: "Performs multi-timeframe technical analysis using TradingView indicators",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Symbol in EXCHANGE:PAIR format (e.g., BINANCE:BTCUSDT)"
        },
        timeframes: %{
          type: :array,
          items: %{type: :string},
          description: "Timeframes to analyze (e.g., [\"15\", \"60\", \"240\", \"D\"])",
          default: ["60", "240", "D"]
        },
        strategy: %{
          type: :string,
          description: "Strategy: trend_following, mean_reversion, momentum, comprehensive",
          default: "comprehensive",
          enum: ["trend_following", "mean_reversion", "momentum", "comprehensive"]
        }
      },
      required: ["symbol"]
    }

  alias Lux.Lenses.TradingView.TechnicalRating

  require Logger

  @timeframe_weights %{
    "1" => 0.05, "5" => 0.10, "15" => 0.15, "30" => 0.15,
    "60" => 0.20, "120" => 0.20, "240" => 0.25,
    "D" => 0.30, "W" => 0.35, "M" => 0.40
  }

  def handler(params, _context) do
    symbol = params["symbol"]
    timeframes = params["timeframes"] || ["60", "240", "D"]
    strategy = params["strategy"] || "comprehensive"

    case fetch_all_timeframes(symbol, timeframes) do
      {:ok, ratings} ->
        analysis = analyze(ratings, strategy)

        {:ok, %{
          symbol: symbol,
          signal: analysis.signal,
          confidence: analysis.confidence,
          strategy: strategy,
          timeframe_analysis: ratings,
          combined_score: analysis.combined_score,
          alignment: analysis.alignment,
          summary: build_summary(analysis),
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        }}

      {:error, reason} ->
        {:error, "Technical analysis failed: #{inspect(reason)}"}
    end
  end

  defp fetch_all_timeframes(symbol, timeframes) do
    results =
      Enum.reduce_while(timeframes, {:ok, %{}}, fn tf, {:ok, acc} ->
        case TechnicalRating.focus(%{symbol: symbol, interval: tf}) do
          {:ok, rating} ->
            {:cont, {:ok, Map.put(acc, tf, rating)}}

          {:error, reason} ->
            Logger.warning("TradingView TA: #{tf} failed for #{symbol}: #{inspect(reason)}")
            {:cont, {:ok, acc}}
        end
      end)

    case results do
      {:ok, ratings} when map_size(ratings) > 0 -> {:ok, ratings}
      {:ok, _} -> {:error, :no_data}
      error -> error
    end
  end

  defp analyze(ratings, strategy) do
    {total_weight, weighted_score} =
      Enum.reduce(ratings, {0.0, 0.0}, fn {tf, rating}, {tw, ws} ->
        weight = Map.get(@timeframe_weights, tf, 0.15)
        score = rating.recommendation_value || 0
        {tw + weight, ws + score * weight}
      end)

    combined = if total_weight > 0, do: weighted_score / total_weight, else: 0
    alignment = calculate_alignment(ratings)
    adjusted = apply_strategy(combined, ratings, strategy)
    confidence = calculate_confidence(adjusted, alignment, map_size(ratings))

    %{
      signal: score_to_signal(adjusted),
      confidence: Float.round(confidence, 2),
      combined_score: Float.round(adjusted, 4),
      alignment: alignment
    }
  end

  defp calculate_alignment(ratings) do
    directions = Enum.map(ratings, fn {_tf, r} -> direction(r.recommendation_value) end)
    total = length(directions)
    bullish = Enum.count(directions, &(&1 == :bullish))
    bearish = Enum.count(directions, &(&1 == :bearish))

    cond do
      bullish == total -> :full_bullish
      bearish == total -> :full_bearish
      bullish > total * 0.7 -> :mostly_bullish
      bearish > total * 0.7 -> :mostly_bearish
      true -> :mixed
    end
  end

  defp direction(v) when is_number(v) and v > 0.1, do: :bullish
  defp direction(v) when is_number(v) and v < -0.1, do: :bearish
  defp direction(_), do: :neutral

  defp apply_strategy(score, ratings, "trend_following") do
    higher = get_higher_tf_score(ratings)
    if score * higher > 0, do: score * 1.2, else: score * 0.7
  end

  defp apply_strategy(score, _ratings, "mean_reversion") do
    if abs(score) > 0.7, do: score * -0.5, else: score
  end

  defp apply_strategy(score, ratings, "momentum") do
    osc = get_oscillator_score(ratings)
    if score * osc > 0, do: score * 1.15, else: score * 0.85
  end

  defp apply_strategy(score, _ratings, _), do: score

  defp get_higher_tf_score(ratings) do
    ["M", "W", "D", "240", "120", "60", "30", "15", "5", "1"]
    |> Enum.find_value(0, fn tf ->
      case Map.get(ratings, tf) do
        %{recommendation_value: v} when is_number(v) -> v
        _ -> nil
      end
    end)
  end

  defp get_oscillator_score(ratings) do
    {sum, count} =
      Enum.reduce(ratings, {0, 0}, fn {_tf, r}, {s, c} ->
        case r do
          %{oscillators: %{recommendation_value: v}} when is_number(v) -> {s + v, c + 1}
          _ -> {s, c}
        end
      end)

    if count > 0, do: sum / count, else: 0
  end

  defp calculate_confidence(score, alignment, tf_count) do
    base = abs(score)

    alignment_bonus =
      case alignment do
        a when a in [:full_bullish, :full_bearish] -> 0.2
        a when a in [:mostly_bullish, :mostly_bearish] -> 0.1
        :mixed -> -0.1
      end

    tf_bonus = min(tf_count * 0.05, 0.15)
    min(max(base + alignment_bonus + tf_bonus, 0.0), 1.0)
  end

  defp score_to_signal(s) when s >= 0.5, do: :strong_buy
  defp score_to_signal(s) when s >= 0.1, do: :buy
  defp score_to_signal(s) when s > -0.1, do: :neutral
  defp score_to_signal(s) when s > -0.5, do: :sell
  defp score_to_signal(_), do: :strong_sell

  defp build_summary(analysis) do
    dir = case analysis.signal do
      s when s in [:strong_buy, :buy] -> "BULLISH"
      s when s in [:strong_sell, :sell] -> "BEARISH"
      _ -> "NEUTRAL"
    end

    str = if analysis.signal in [:strong_buy, :strong_sell], do: "STRONG", else: "MODERATE"

    "#{dir} (#{str}) | Confidence: #{Float.round(analysis.confidence * 100, 1)}% | Alignment: #{analysis.alignment}"
  end
end
