defmodule Lux.Prisms.TradingView.BacktestStrategy do
  @moduledoc """
  Runs a TradingView-style moving-average crossover backtest.
  """

  use Lux.Prism,
    name: "Backtest TradingView Strategy",
    description: "Backtests a moving-average crossover strategy over normalized OHLCV bars",
    input_schema: %{
      type: :object,
      properties: %{
        bars: %{type: :array, description: "OHLCV bars"},
        fast_period: %{type: :integer},
        slow_period: %{type: :integer},
        initial_cash: %{type: :number}
      },
      required: ["bars"]
    },
    output_schema: %{type: :object}

  alias Lux.Integrations.TradingView.TechnicalAnalysis

  @impl true
  def handler(params, _agent) do
    bars = fetch_param(params, :bars) || []
    strategy = Map.drop(params, [:bars, "bars"])

    {:ok,
     TechnicalAnalysis.backtest_strategy(TechnicalAnalysis.normalize_chart(bars).bars, strategy)}
  end

  defp fetch_param(params, key) when is_map(params),
    do:
      if(Map.has_key?(params, key),
        do: Map.get(params, key),
        else: Map.get(params, Atom.to_string(key))
      )
end
