defmodule Lux.Prisms.TradingView.StrategyBacktestPrism do
  @moduledoc """
  Simulates indicator strategies on historical prices and computes performance statistics.
  """

  use Lux.Prism,
    name: "TradingView Strategy Backtest",
    description: "Simulates indicator trading strategies and computes win rate %, total return, and max drawdown",
    input_schema: %{
      type: :object,
      properties: %{
        prices: %{type: :array, description: "Historical close prices series"},
        fast_ma: %{type: :integer, default: 9},
        slow_ma: %{type: :integer, default: 21}
      },
      required: ["prices"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        total_trades: %{type: :integer},
        win_rate_pct: %{type: :number},
        total_return_pct: %{type: :number},
        profit_factor: %{type: :number},
        max_drawdown_pct: %{type: :number}
      },
      required: ["total_trades", "win_rate_pct", "total_return_pct"]
    }

  alias Lux.TradingView.Backtester

  def handler(input, _ctx) do
    prices = Map.get(input, :prices) || Map.get(input, "prices", [])
    fast_ma = Map.get(input, :fast_ma) || Map.get(input, "fast_ma", 9)
    slow_ma = Map.get(input, :slow_ma) || Map.get(input, "slow_ma", 21)

    result = Backtester.run_backtest(prices, fast_ma, slow_ma)
    {:ok, result}
  end
end
