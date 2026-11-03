defmodule Lux.Prisms.TradingView.TradingViewAlertPrism do
  @moduledoc """
  Generates and assesses technical alert events (RSI extreme, MACD cross, Bollinger breakout, PineScript).
  Wraps `Lux.TradingView.Alerts`.
  """

  use Lux.Prism,
    name: "TradingView Alert Prism",
    description: "Evaluates trigger conditions for indicator alerts and threshold breaches",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Market symbol", default: "UNKNOWN"},
        current_price: %{type: :number},
        rsi: %{type: :number},
        macd: %{type: :object},
        bollinger_bands: %{type: :object},
        alerts: %{type: :array, description: "List of custom alert rules"}
      },
      required: ["current_price"]
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

  alias Lux.TradingView.Alerts

  def handler(input, _ctx) do
    symbol = Map.get(input, :symbol) || Map.get(input, "symbol", "UNKNOWN")
    price = (Map.get(input, :current_price) || Map.get(input, "current_price", 0.0)) * 1.0
    rsi = Map.get(input, :rsi) || Map.get(input, "rsi")
    macd = Map.get(input, :macd) || Map.get(input, "macd")
    bb = Map.get(input, :bollinger_bands) || Map.get(input, "bollinger_bands")

    rules =
      case Map.get(input, :alerts) || Map.get(input, "alerts") do
        list when is_list(list) ->
          list

        _ ->
          # Default core alerts (RSI extremes & Bollinger breaches)
          [
            %{id: "rsi_high", symbol: symbol, condition: :rsi_overbought, threshold: 70.0},
            %{id: "rsi_low", symbol: symbol, condition: :rsi_oversold, threshold: 30.0},
            %{id: "bb_high", symbol: symbol, condition: :bb_breakout_upper},
            %{id: "bb_low", symbol: symbol, condition: :bb_breakout_lower}
          ]
      end

    snapshot = %{
      symbol: symbol,
      current_price: price,
      rsi: rsi,
      macd: macd,
      bollinger_bands: bb
    }

    {:ok, %{triggered_alerts: triggered}} = Alerts.evaluate_alerts(rules, snapshot)

    {:ok,
     %{
       symbol: symbol,
       has_alerts?: length(triggered) > 0,
       alerts: triggered
     }}
  end
end
