defmodule Lux.Prisms.TradingView.TradingViewAlertPrism do
  @moduledoc """
  Generates and assesses technical alert events (RSI extreme, MACD cross, Bollinger breakout).
  """

  use Lux.Prism,
    name: "TradingView Alert Prism",
    description: "Evaluates trigger conditions for indicator alerts and threshold breaches",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Market symbol"},
        rsi: %{type: :number},
        macd_histogram: %{type: :number},
        current_price: %{type: :number},
        upper_band: %{type: :number},
        lower_band: %{type: :number}
      },
      required: ["symbol", "current_price"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string},
        has_alerts?: %{type: :boolean},
        alerts: %{type: :array}
      },
      required: ["symbol", "has_alerts?", "alerts"]
    }

  def handler(input, _ctx) do
    symbol = Map.get(input, :symbol) || Map.get(input, "symbol", "UNKNOWN")
    rsi = Map.get(input, :rsi) || Map.get(input, "rsi")
    hist = Map.get(input, :macd_histogram) || Map.get(input, "macd_histogram")
    price = (Map.get(input, :current_price) || Map.get(input, "current_price", 0.0)) * 1.0
    upper = Map.get(input, :upper_band) || Map.get(input, "upper_band")
    lower = Map.get(input, :lower_band) || Map.get(input, "lower_band")

    alerts = []

    alerts =
      cond do
        rsi && rsi >= 70.0 ->
          [%{type: :rsi_overbought, message: "RSI is overbought at #{rsi}"} | alerts]

        rsi && rsi <= 30.0 ->
          [%{type: :rsi_oversold, message: "RSI is oversold at #{rsi}"} | alerts]

        true ->
          alerts
      end

    alerts =
      cond do
        upper && price >= upper ->
          [%{type: :bb_breakout_high, message: "Price #{price} pierced upper Bollinger Band #{upper}"} | alerts]

        lower && price <= lower ->
          [%{type: :bb_breakout_low, message: "Price #{price} pierced lower Bollinger Band #{lower}"} | alerts]

        true ->
          alerts
      end

    alerts =
      cond do
        hist && hist > 0.0 ->
          [%{type: :macd_bullish_histogram, message: "MACD Histogram turned positive (+#{hist})"} | alerts]

        hist && hist < 0.0 ->
          [%{type: :macd_bearish_histogram, message: "MACD Histogram turned negative (#{hist})"} | alerts]

        true ->
          alerts
      end

    {:ok,
     %{
       symbol: symbol,
       has_alerts?: length(alerts) > 0,
       alerts: alerts
     }}
  end
end
