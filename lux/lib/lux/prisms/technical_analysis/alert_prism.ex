defmodule Lux.Prisms.TechnicalAnalysis.AlertManager do
  @moduledoc """
  A prism that manages technical analysis alerts and generates alert signals.

  Supports threshold-based alerts for RSI, price, MACD, and Bollinger Bands.
  Alerts can trigger buy/sell signals when conditions are met.

  ## Examples

      iex> Lux.Prisms.TechnicalAnalysis.AlertManager.run(%{
      ...>   indicators: %{rsi: 72.5, macd_histogram: 0.5, bb_pct_b: 1.1},
      ...>   alerts: [
      ...>     %{type: "rsi_overbought", threshold: 70},
      ...>     %{type: "price_above_bb", threshold: 1.0}
      ...>   ]
      ...> })
      {:ok, %{alerts_triggered: [...], signals: [...]}}
  """

  use Lux.Prism,
    name: "Alert Manager",
    description: "Manages technical analysis alerts and generates trading signals",
    input_schema: %{
      type: :object,
      properties: %{
        indicators: %{
          type: :object,
          description: "Current indicator values",
          properties: %{
            rsi: %{type: :number},
            macd: %{type: :number},
            macd_histogram: %{type: :number},
            bb_pct_b: %{type: :number},
            bb_bandwidth: %{type: :number}
          }
        },
        alerts: %{
          type: :array,
          description: "List of alert definitions",
          items: %{
            type: :object,
            properties: %{
              type: %{type: :string, enum: ["rsi_overbought", "rsi_oversold", "price_above_bb", "price_below_bb", "macd_bullish_cross", "macd_bearish_cross", "low_volume_spike"]},
              threshold: %{type: :number}
            }
          }
        },
        sensitivity: %{
          type: :number,
          description: "Alert sensitivity multiplier (default 1.0)",
          default: 1.0
        }
      },
      required: ["indicators", "alerts"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        alerts_triggered: %{type: :array, description: "List of triggered alerts"},
        signals: %{type: :array, description: "Generated trading signals"},
        overall_sentiment: %{
          type: :string,
          enum: ["bullish", "bearish", "neutral"],
          description: "Combined signal sentiment"
        },
        confidence: %{type: :number, description: "Overall confidence 0-1"}
      },
      required: ["alerts_triggered", "signals", "overall_sentiment", "confidence"]
    }

  def handler(%{indicators: indicators, alerts: alerts} = input, _ctx) do
    sensitivity = Map.get(input, :sensitivity, 1.0)

    triggered =
      alerts
      |> Enum.filter(fn alert -> alert_triggered?(alert, indicators, sensitivity) end)
      |> Enum.map(fn alert -> alert_result(alert, indicators) end)

    signals = generate_signals(triggered)
    sentiment = determine_sentiment(signals)
    confidence = calculate_confidence(signals, triggered)

    {:ok, %{
      alerts_triggered: triggered,
      signals: signals,
      overall_sentiment: sentiment,
      confidence: Float.round(confidence, 2)
    }}
  end

  def handler(input, _ctx) do
    {:error, "invalid input: #{inspect(input)}"}
  end

  defp alert_triggered?(alert, indicators, sensitivity) do
    case alert.type do
      "rsi_overbought" ->
        Map.get(indicators, :rsi, 0) >= alert.threshold / sensitivity

      "rsi_oversold" ->
        Map.get(indicators, :rsi, 100) <= alert.threshold * sensitivity

      "price_above_bb" ->
        Map.get(indicators, :bb_pct_b, 0) >= alert.threshold / sensitivity

      "price_below_bb" ->
        Map.get(indicators, :bb_pct_b, 1) <= alert.threshold * sensitivity

      "macd_bullish_cross" ->
        Map.get(indicators, :macd_histogram, 0) > alert.threshold

      "macd_bearish_cross" ->
        Map.get(indicators, :macd_histogram, 0) < alert.threshold

      _ ->
        false
    end
  end

  defp alert_result(alert, indicators) do
    %{
      type: alert.type,
      threshold: alert.threshold,
      current_value: current_value(alert.type, indicators),
      triggered: true,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp current_value("rsi_overbought", indicators), do: Map.get(indicators, :rsi, 0)
  defp current_value("rsi_oversold", indicators), do: Map.get(indicators, :rsi, 100)
  defp current_value("price_above_bb", indicators), do: Map.get(indicators, :bb_pct_b, 0)
  defp current_value("price_below_bb", indicators), do: Map.get(indicators, :bb_pct_b, 1)
  defp current_value("macd_bullish_cross", indicators), do: Map.get(indicators, :macd_histogram, 0)
  defp current_value("macd_bearish_cross", indicators), do: Map.get(indicators, :macd_histogram, 0)
  defp current_value(_, _), do: 0

  defp generate_signals(triggered) do
    triggered
    |> Enum.map(fn alert ->
      cond do
        alert.type in ["rsi_oversold", "macd_bullish_cross", "price_below_bb"] ->
          %{type: "buy", strength: alert_strength(alert), source: alert.type}

        alert.type in ["rsi_overbought", "macd_bearish_cross", "price_above_bb"] ->
          %{type: "sell", strength: alert_strength(alert), source: alert.type}

        true ->
          %{type: "neutral", strength: 0.5, source: alert.type}
      end
    end)
  end

  defp alert_strength(alert) do
    diff = abs(alert.current_value - alert.threshold)
    threshold = max(alert.threshold * 0.1, 1)
    min(diff / threshold + 0.5, 1.0)
  end

  defp determine_sentiment(signals) do
    buys = Enum.count(signals, &(&1.type == "buy"))
    sells = Enum.count(signals, &(&1.type == "sell"))
    total = length(signals)

    cond do
      total == 0 -> "neutral"
      buys > sells -> "bullish"
      sells > buys -> "bearish"
      true -> "neutral"
    end
  end

  defp calculate_confidence(signals, triggered) do
    if length(signals) == 0 do
      0.0
    else
      avg_strength =
        signals
        |> Enum.map(& &1.strength)
        |> Enum.reduce(0, &+/2) / length(signals)

      agreement =
        case determine_sentiment(signals) do
          "bullish" -> Enum.count(signals, &(&1.type == "buy")) / length(signals)
          "bearish" -> Enum.count(signals, &(&1.type == "sell")) / length(signals)
          _ -> 0.5
        end

      Float.round(avg_strength * agreement, 2)
    end
  end
end
