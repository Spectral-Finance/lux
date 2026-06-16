defmodule Lux.Prisms.TradingView.BacktestSmaCross do
  @moduledoc """
  Runs a simple SMA crossover backtest over OHLCV candles.
  """

  use Lux.Prism,
    name: "Backtest TradingView SMA Cross",
    description: "Backtests a fast/slow SMA crossover strategy over OHLCV candles",
    input_schema: %{
      type: :object,
      properties: %{
        candles: %{type: :array},
        fast_period: %{type: :integer},
        slow_period: %{type: :integer}
      },
      required: ["candles"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        backtest: %{type: :object}
      },
      required: ["backtest"]
    }

  alias Lux.Integrations.TradingView.TechnicalAnalysis

  @impl true
  def handler(params, _ctx) do
    candles = Map.get(params, :candles, Map.get(params, "candles", []))
    fast_period = Map.get(params, :fast_period, Map.get(params, "fast_period", 5))
    slow_period = Map.get(params, :slow_period, Map.get(params, "slow_period", 20))

    with {:ok, backtest} <-
           TechnicalAnalysis.backtest_sma_cross(candles, fast_period, slow_period) do
      {:ok, %{backtest: backtest}}
    end
  end
end
