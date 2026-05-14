defmodule Lux.Prisms.TradingView.AnalyzeChart do
  @moduledoc """
  Runs TradingView-style chart technical analysis.
  """

  use Lux.Prism,
    name: "Analyze TradingView Chart",
    description:
      "Normalizes OHLCV bars and calculates indicators, alerts, signals, backtest, and timeframe summaries",
    input_schema: %{
      type: :object,
      properties: %{
        bars: %{type: :array, description: "OHLCV bars"},
        symbol: %{type: :string},
        timeframe: %{type: :string},
        indicators: %{type: :object},
        alerts: %{type: :array},
        strategy: %{type: :object}
      },
      required: ["bars"]
    },
    output_schema: %{type: :object}

  alias Lux.Integrations.TradingView.TechnicalAnalysis

  @impl true
  def handler(params, _agent) do
    bars = fetch_param(params, :bars) || []
    opts = Map.drop(params, [:bars, "bars"])

    {:ok, TechnicalAnalysis.analyze(bars, opts)}
  end

  defp fetch_param(params, key) when is_map(params),
    do:
      if(Map.has_key?(params, key),
        do: Map.get(params, key),
        else: Map.get(params, Atom.to_string(key))
      )
end
