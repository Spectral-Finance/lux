defmodule Lux.Prisms.TradingView.StrategyBacktester do
  @moduledoc """
  A prism that backtests trading strategies using TradingView technical analysis data.

  Evaluates a trading strategy by analyzing indicator-based entry and exit conditions
  against current market data across multiple timeframes. This provides a snapshot-based
  strategy evaluation rather than historical bar-by-bar backtesting.

  ## Strategy Definition

  A strategy consists of:
  - **Entry conditions**: Indicator conditions that must be met to enter a trade
  - **Exit conditions**: Indicator conditions that trigger trade exit
  - **Stop loss**: Percentage-based stop loss level
  - **Take profit**: Percentage-based take profit level

  ## Examples

      iex> Lux.Prisms.TradingView.StrategyBacktester.run(%{
      ...>   symbol: "TSLA",
      ...>   exchange: "NASDAQ",
      ...>   screener: "america",
      ...>   strategy: %{
      ...>     name: "RSI Reversal",
      ...>     entry_conditions: [
      ...>       %{indicator: "RSI", operator: "below", value: 30},
      ...>       %{indicator: "MACD.macd", operator: "crosses_above", value2: "MACD.signal"}
      ...>     ],
      ...>     exit_conditions: [
      ...>       %{indicator: "RSI", operator: "above", value: 70}
      ...>     ],
      ...>     stop_loss_pct: 5.0,
      ...>     take_profit_pct: 15.0
      ...>   },
      ...>   intervals: ["1h", "4h", "1d"]
      ...> })
      {:ok, %{
        symbol: "NASDAQ:TSLA",
        strategy_name: "RSI Reversal",
        timeframe_results: %{
          "1h" => %{entry_met: true, exit_met: false, ...},
          "4h" => %{entry_met: false, exit_met: false, ...},
          "1d" => %{entry_met: true, exit_met: false, ...}
        },
        current_price: 253.80,
        stop_loss_price: 241.11,
        take_profit_price: 291.87,
        overall_signal: "ENTRY",
        risk_reward_ratio: 3.0
      }}
  """

  use Lux.Prism,
    name: "TradingView Strategy Backtester",
    description: "Backtests trading strategies against TradingView technical analysis data",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading symbol"
        },
        exchange: %{
          type: :string,
          description: "Exchange name"
        },
        screener: %{
          type: :string,
          description: "Market screener region",
          default: "america"
        },
        strategy: %{
          type: :object,
          description: "Strategy definition",
          properties: %{
            name: %{type: :string, description: "Strategy name"},
            entry_conditions: %{
              type: :array,
              description: "Entry conditions",
              items: %{type: :object}
            },
            exit_conditions: %{
              type: :array,
              description: "Exit conditions",
              items: %{type: :object}
            },
            stop_loss_pct: %{
              type: :number,
              description: "Stop loss percentage",
              default: 5.0
            },
            take_profit_pct: %{
              type: :number,
              description: "Take profit percentage",
              default: 10.0
            }
          },
          required: ["name", "entry_conditions"]
        },
        intervals: %{
          type: :array,
          description: "Timeframes to evaluate",
          items: %{type: :string},
          default: ["1h", "4h", "1d"]
        }
      },
      required: ["symbol", "exchange", "strategy"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string},
        strategy_name: %{type: :string},
        timeframe_results: %{type: :object},
        current_price: %{type: :number},
        stop_loss_price: %{type: :number},
        take_profit_price: %{type: :number},
        overall_signal: %{type: :string, enum: ["ENTRY", "EXIT", "HOLD", "NO_SIGNAL"]},
        risk_reward_ratio: %{type: :number}
      },
      required: ["symbol", "strategy_name", "overall_signal"]
    }

  alias Lux.Integrations.TradingView
  alias Lux.Integrations.TradingView.Client

  def handler(input, _ctx) do
    symbol = Map.fetch!(input, :symbol)
    exchange = Map.fetch!(input, :exchange)
    screener = Map.get(input, :screener, "america")
    strategy = Map.fetch!(input, :strategy)
    intervals = Map.get(input, :intervals, ["1h", "4h", "1d"])

    ticker = TradingView.format_ticker(symbol, exchange)

    # Collect all needed indicators from strategy conditions
    needed_columns = extract_strategy_columns(strategy) ++ ["close"]

    # Evaluate strategy across each timeframe
    timeframe_results =
      Enum.reduce(intervals, %{}, fn interval, acc ->
        body = Client.build_scan_body([ticker], needed_columns, interval)

        case Client.scan(screener, body) do
          {:ok, response} ->
            interval_cols = Enum.map(needed_columns, &TradingView.column_with_interval(&1, interval))
            parsed = Client.parse_scan_response(response, interval_cols)

            case Map.get(parsed, ticker) do
              nil ->
                Map.put(acc, interval, %{error: "No data available"})

              data ->
                result = evaluate_strategy_timeframe(strategy, data)
                Map.put(acc, interval, result)
            end

          {:error, _reason} ->
            Map.put(acc, interval, %{error: "Failed to fetch data"})
        end
      end)

    # Get current price from the first successful result
    current_price =
      timeframe_results
      |> Map.values()
      |> Enum.find_value(fn
        %{current_price: price} when is_number(price) -> price
        _ -> nil
      end)

    # Determine overall signal
    overall_signal = determine_overall_signal(timeframe_results)

    # Calculate risk/reward levels
    stop_loss_pct = Map.get(strategy, :stop_loss_pct, 5.0)
    take_profit_pct = Map.get(strategy, :take_profit_pct, 10.0)

    {stop_loss_price, take_profit_price, risk_reward_ratio} =
      if is_number(current_price) do
        sl = Float.round(current_price * (1 - stop_loss_pct / 100), 2)
        tp = Float.round(current_price * (1 + take_profit_pct / 100), 2)
        rr = if stop_loss_pct > 0, do: Float.round(take_profit_pct / stop_loss_pct, 2), else: 0.0
        {sl, tp, rr}
      else
        {nil, nil, 0.0}
      end

    {:ok, %{
      symbol: ticker,
      strategy_name: strategy.name,
      timeframe_results: timeframe_results,
      current_price: current_price,
      stop_loss_price: stop_loss_price,
      take_profit_price: take_profit_price,
      overall_signal: overall_signal,
      risk_reward_ratio: risk_reward_ratio
    }}
  end

  defp extract_strategy_columns(strategy) do
    entry_cols = extract_condition_columns(Map.get(strategy, :entry_conditions, []))
    exit_cols = extract_condition_columns(Map.get(strategy, :exit_conditions, []))

    (entry_cols ++ exit_cols)
    |> Enum.uniq()
  end

  defp extract_condition_columns(conditions) when is_list(conditions) do
    Enum.flat_map(conditions, fn condition ->
      cols = if condition[:indicator], do: [condition[:indicator]], else: []
      cols = if condition[:value2], do: [condition[:value2] | cols], else: cols
      cols
    end)
  end

  defp extract_condition_columns(_), do: []

  defp evaluate_strategy_timeframe(strategy, data) do
    entry_conditions = Map.get(strategy, :entry_conditions, [])
    exit_conditions = Map.get(strategy, :exit_conditions, [])

    entry_results = Enum.map(entry_conditions, &evaluate_single_condition(&1, data))
    exit_results = Enum.map(exit_conditions, &evaluate_single_condition(&1, data))

    entry_met = length(entry_results) > 0 and Enum.all?(entry_results, & &1.met)
    exit_met = length(exit_results) > 0 and Enum.all?(exit_results, & &1.met)

    %{
      entry_met: entry_met,
      exit_met: exit_met,
      entry_details: entry_results,
      exit_details: exit_results,
      current_price: data["close"]
    }
  end

  defp evaluate_single_condition(condition, data) do
    indicator = condition[:indicator]
    operator = Map.get(condition, :operator, "above")
    value = condition[:value]
    value2_name = condition[:value2]

    current_value = data[indicator]

    compare_value =
      if value2_name do
        data[value2_name]
      else
        value
      end

    met =
      cond do
        is_nil(current_value) or is_nil(compare_value) ->
          false

        operator in ["above", "crosses_above"] ->
          current_value > compare_value

        operator in ["below", "crosses_below"] ->
          current_value < compare_value

        operator == "equals" ->
          abs(current_value - compare_value) < 0.001

        true ->
          false
      end

    %{
      indicator: indicator,
      operator: operator,
      target: compare_value,
      current: current_value,
      met: met
    }
  end

  defp determine_overall_signal(timeframe_results) do
    valid_results =
      timeframe_results
      |> Map.values()
      |> Enum.filter(&(not Map.has_key?(&1, :error)))

    if Enum.empty?(valid_results) do
      "NO_SIGNAL"
    else
      entry_count = Enum.count(valid_results, & &1.entry_met)
      exit_count = Enum.count(valid_results, & &1.exit_met)
      total = length(valid_results)

      cond do
        # Majority of timeframes show exit → EXIT
        exit_count > total / 2 -> "EXIT"
        # Majority of timeframes show entry → ENTRY
        entry_count > total / 2 -> "ENTRY"
        # Any timeframe shows entry → HOLD (partial signal)
        entry_count > 0 -> "HOLD"
        true -> "NO_SIGNAL"
      end
    end
  end
end
