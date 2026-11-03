defmodule Lux.Prisms.TradingView.SignalGeneratorPrism do
  @moduledoc """
  Generates consolidated technical analysis signals and bias recommendations.
  """

  use Lux.Prism,
    name: "TradingView Signal Generator",
    description: "Evaluates multi-indicator bias and outputs composite score and recommendation",
    input_schema: %{
      type: :object,
      properties: %{
        current_price: %{type: :number, description: "Current asset market price"},
        rsi: %{type: :number, description: "Calculated RSI value"},
        macd: %{type: :object, description: "Calculated MACD line and histogram"},
        bollinger_bands: %{type: :object, description: "Calculated Bollinger Bands"},
        stochastic: %{type: :object, description: "Calculated Stochastic oscillator"}
      },
      required: ["current_price"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        score: %{type: :integer},
        recommendation: %{type: :string},
        rsi_signal: %{type: :string},
        macd_signal: %{type: :string},
        bb_signal: %{type: :string},
        stoch_signal: %{type: :string}
      },
      required: ["score", "recommendation"]
    }

  alias Lux.TradingView.Signals

  def handler(input, _ctx) do
    current_price = (Map.get(input, :current_price) || Map.get(input, "current_price", 0.0)) * 1.0
    rsi = Map.get(input, :rsi) || Map.get(input, "rsi")
    macd = Map.get(input, :macd) || Map.get(input, "macd")
    bb = Map.get(input, :bollinger_bands) || Map.get(input, "bollinger_bands")
    stoch = Map.get(input, :stochastic) || Map.get(input, "stochastic")

    sig = Signals.generate_signal(current_price, rsi, macd, bb, stoch)

    {:ok,
     %{
       score: sig.score,
       recommendation: to_string(sig.recommendation) |> String.upcase(),
       rsi_signal: to_string(sig.rsi_signal),
       macd_signal: to_string(sig.macd_signal),
       bb_signal: to_string(sig.bb_signal),
       stoch_signal: to_string(sig.stoch_signal)
     }}
  end
end
