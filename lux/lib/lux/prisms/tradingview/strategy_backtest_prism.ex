defmodule Lux.Prisms.TradingView.StrategyBacktestPrism do
  @moduledoc """
  Simulates indicator strategies on historical prices and computes performance statistics.
  """

  use Lux.Prism,
    name: "TradingView Strategy Backtest",
    description:
      "Simulates indicator trading strategies and computes win rate %, total return, and max drawdown",
    input_schema: %{
      type: :object,
      properties: %{
        prices: %{type: :array, description: "Historical close prices series"},
        candles: %{type: :array, description: "Historical candlestick series"},
        strategy: %{
          type: :string,
          description: "Strategy: ma_crossover, rsi_reversal, bollinger_breakout",
          default: "ma_crossover"
        },
        fast_ma: %{type: :integer, default: 9},
        slow_ma: %{type: :integer, default: 21}
      }
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
    data =
      cond do
        Map.has_key?(input, :prices) -> Map.get(input, :prices)
        Map.has_key?(input, "prices") -> Map.get(input, "prices")
        Map.has_key?(input, :candles) -> Map.get(input, :candles)
        Map.has_key?(input, "candles") -> Map.get(input, "candles")
        true -> []
      end

    strategy_str = Map.get(input, :strategy) || Map.get(input, "strategy", "ma_crossover")
    strategy_atom = String.to_atom(to_string(strategy_str))

    opts = %{
      fast_ma: Map.get(input, :fast_ma) || Map.get(input, "fast_ma", 9),
      slow_ma: Map.get(input, :slow_ma) || Map.get(input, "slow_ma", 21)
    }

    result = Backtester.run_backtest(data, strategy_atom, opts)
    {:ok, result}
  end
end
