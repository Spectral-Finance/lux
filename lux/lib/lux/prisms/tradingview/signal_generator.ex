defmodule Lux.Prisms.TradingView.SignalGenerator do
  @moduledoc """
  Prism for generating actionable trading signals with entry/exit levels.

  Combines TechnicalAnalysis with price data to produce complete signals:
  - Direction (long/short/neutral)
  - Entry price zone
  - Stop-loss level
  - Take-profit targets (3 levels)
  - Risk/reward ratio
  - Confidence score

  ## Examples

      iex> SignalGenerator.handler(%{
      ...>   "symbol" => "BINANCE:BTCUSDT",
      ...>   "risk_pct" => 2.0
      ...> }, nil)
      {:ok, %{direction: :long, entry: %{...}, stop_loss: 66200.0, ...}}
  """

  use Lux.Prism,
    name: "TradingView Signal Generator",
    description: "Generates trading signals with entry/exit levels from TradingView TA",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Symbol in EXCHANGE:PAIR format"},
        risk_pct: %{type: :number, description: "Risk percentage per trade (default: 2.0)", default: 2.0},
        timeframe: %{type: :string, description: "Primary timeframe", default: "60"}
      },
      required: ["symbol"]
    }

  alias Lux.Lenses.TradingView.ChartData
  alias Lux.Prisms.TradingView.TechnicalAnalysis

  def handler(params, context) do
    symbol = params["symbol"]
    risk_pct = params["risk_pct"] || 2.0
    timeframe = params["timeframe"] || "60"

    with {:ok, ta} <- TechnicalAnalysis.handler(
           %{"symbol" => symbol, "timeframes" => [timeframe, "240", "D"]},
           context
         ),
         {:ok, chart} <- ChartData.focus(%{symbol: symbol, interval: timeframe}) do
      price = extract_price(chart)
      signal = generate_signal(ta, price, risk_pct)

      {:ok, Map.merge(signal, %{
        symbol: symbol,
        timeframe: timeframe,
        analysis: ta.summary,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })}
    else
      {:error, reason} -> {:error, "Signal generation failed: #{inspect(reason)}"}
    end
  end

  defp extract_price(%{data: [%{close: close} | _]}) when is_number(close), do: close
  defp extract_price(_), do: nil

  defp generate_signal(ta, price, risk_pct) when is_number(price) do
    direction = case ta.signal do
      s when s in [:strong_buy, :buy] -> :long
      s when s in [:strong_sell, :sell] -> :short
      _ -> :neutral
    end

    atr_est = price * 0.015
    risk_amt = price * (risk_pct / 100)

    case direction do
      :long ->
        %{
          direction: :long,
          entry: %{low: Float.round(price * 0.998, 2), high: Float.round(price * 1.002, 2)},
          stop_loss: Float.round(price - atr_est * 1.5, 2),
          take_profit: [
            Float.round(price + atr_est * 1.5, 2),
            Float.round(price + atr_est * 2.5, 2),
            Float.round(price + atr_est * 4.0, 2)
          ],
          risk_reward: Float.round(atr_est * 2.5 / risk_amt, 2),
          confidence: ta.confidence
        }

      :short ->
        %{
          direction: :short,
          entry: %{low: Float.round(price * 0.998, 2), high: Float.round(price * 1.002, 2)},
          stop_loss: Float.round(price + atr_est * 1.5, 2),
          take_profit: [
            Float.round(price - atr_est * 1.5, 2),
            Float.round(price - atr_est * 2.5, 2),
            Float.round(price - atr_est * 4.0, 2)
          ],
          risk_reward: Float.round(atr_est * 2.5 / risk_amt, 2),
          confidence: ta.confidence
        }

      :neutral ->
        %{direction: :neutral, entry: nil, stop_loss: nil, take_profit: [], risk_reward: 0, confidence: ta.confidence}
    end
  end

  defp generate_signal(ta, _price, _risk_pct) do
    %{direction: :neutral, entry: nil, stop_loss: nil, take_profit: [], risk_reward: 0,
      confidence: ta.confidence, note: "Unable to determine current price"}
  end
end
