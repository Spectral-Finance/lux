defmodule Lux.Prisms.TradingView.AlertManager do
  @moduledoc """
  A prism that manages trading alerts based on TradingView technical analysis conditions.

  Creates, evaluates, and triggers alerts when specified indicator conditions are met.
  Supports multiple condition types including threshold crossings, crossovers,
  and composite conditions.

  ## Condition Types

  - **threshold**: Triggers when an indicator crosses above or below a value
  - **crossover**: Triggers when one indicator crosses another
  - **recommendation**: Triggers when the overall recommendation matches a target

  ## Examples

      # Create a price alert
      iex> Lux.Prisms.TradingView.AlertManager.run(%{
      ...>   action: "evaluate",
      ...>   symbol: "TSLA",
      ...>   exchange: "NASDAQ",
      ...>   screener: "america",
      ...>   interval: "1d",
      ...>   conditions: [
      ...>     %{type: "threshold", indicator: "RSI", operator: "below", value: 30},
      ...>     %{type: "threshold", indicator: "close", operator: "above", value: 250.0}
      ...>   ]
      ...> })
      {:ok, %{
        symbol: "NASDAQ:TSLA",
        alerts_triggered: [
          %{condition: "RSI below 30", triggered: true, current_value: 28.5}
        ],
        alerts_not_triggered: [
          %{condition: "close above 250.0", triggered: false, current_value: 245.30}
        ],
        any_triggered: true
      }}
  """

  use Lux.Prism,
    name: "TradingView Alert Manager",
    description: "Evaluates trading alert conditions against TradingView technical analysis data",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          description: "Alert action to perform",
          enum: ["evaluate"],
          default: "evaluate"
        },
        symbol: %{
          type: :string,
          description: "Trading symbol (e.g., TSLA, BTCUSD)"
        },
        exchange: %{
          type: :string,
          description: "Exchange name (e.g., NASDAQ, BINANCE)"
        },
        screener: %{
          type: :string,
          description: "Market screener region",
          default: "america"
        },
        interval: %{
          type: :string,
          description: "Time interval",
          enum: ["1m", "5m", "15m", "30m", "1h", "2h", "4h", "1d", "1W", "1M"],
          default: "1d"
        },
        conditions: %{
          type: :array,
          description: "List of alert conditions to evaluate",
          items: %{
            type: :object,
            properties: %{
              type: %{
                type: :string,
                enum: ["threshold", "crossover", "recommendation"],
                description: "Condition type"
              },
              indicator: %{
                type: :string,
                description: "Indicator name (e.g., RSI, MACD.macd, close)"
              },
              operator: %{
                type: :string,
                enum: ["above", "below", "crosses_above", "crosses_below", "equals"],
                description: "Comparison operator"
              },
              value: %{
                type: :number,
                description: "Threshold value for comparison"
              },
              indicator2: %{
                type: :string,
                description: "Second indicator for crossover conditions"
              },
              target: %{
                type: :string,
                description: "Target recommendation for recommendation conditions"
              }
            },
            required: ["type"]
          }
        }
      },
      required: ["symbol", "exchange", "conditions"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Ticker symbol"},
        alerts_triggered: %{
          type: :array,
          description: "List of triggered alerts"
        },
        alerts_not_triggered: %{
          type: :array,
          description: "List of alerts that were not triggered"
        },
        any_triggered: %{
          type: :boolean,
          description: "Whether any alert was triggered"
        }
      },
      required: ["symbol", "alerts_triggered", "alerts_not_triggered", "any_triggered"]
    }

  alias Lux.Integrations.TradingView
  alias Lux.Integrations.TradingView.Client

  def handler(input, _ctx) do
    symbol = Map.fetch!(input, :symbol)
    exchange = Map.fetch!(input, :exchange)
    screener = Map.get(input, :screener, "america")
    interval = Map.get(input, :interval, "1d")
    conditions = Map.fetch!(input, :conditions)

    ticker = TradingView.format_ticker(symbol, exchange)

    # Collect all indicator names needed from conditions
    needed_indicators = extract_needed_indicators(conditions)

    # Always include recommendation columns
    columns =
      (TradingView.recommendation_columns() ++ needed_indicators)
      |> Enum.uniq()

    body = Client.build_scan_body([ticker], columns, interval)

    case Client.scan(screener, body) do
      {:ok, response} ->
        interval_columns = Enum.map(columns, &TradingView.column_with_interval(&1, interval))
        parsed = Client.parse_scan_response(response, interval_columns)

        case Map.get(parsed, ticker) do
          nil ->
            {:error, "No data returned for #{ticker}"}

          data ->
            {triggered, not_triggered} = evaluate_conditions(conditions, data)

            {:ok, %{
              symbol: ticker,
              alerts_triggered: triggered,
              alerts_not_triggered: not_triggered,
              any_triggered: length(triggered) > 0
            }}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_needed_indicators(conditions) do
    conditions
    |> Enum.flat_map(fn condition ->
      indicators = []
      indicators = if condition[:indicator], do: [condition[:indicator] | indicators], else: indicators
      indicators = if condition[:indicator2], do: [condition[:indicator2] | indicators], else: indicators
      indicators
    end)
    |> Enum.uniq()
  end

  defp evaluate_conditions(conditions, data) do
    Enum.reduce(conditions, {[], []}, fn condition, {triggered, not_triggered} ->
      result = evaluate_condition(condition, data)

      if result.triggered do
        {triggered ++ [result], not_triggered}
      else
        {triggered, not_triggered ++ [result]}
      end
    end)
  end

  defp evaluate_condition(%{type: "threshold"} = condition, data) do
    indicator = condition.indicator
    operator = condition.operator
    threshold = condition.value
    current_value = data[indicator]

    triggered =
      case operator do
        "above" -> is_number(current_value) and current_value > threshold
        "below" -> is_number(current_value) and current_value < threshold
        "equals" -> is_number(current_value) and abs(current_value - threshold) < 0.001
        _ -> false
      end

    %{
      condition: "#{indicator} #{operator} #{threshold}",
      triggered: triggered,
      current_value: current_value
    }
  end

  defp evaluate_condition(%{type: "crossover"} = condition, data) do
    ind1 = condition.indicator
    ind2 = condition.indicator2
    operator = Map.get(condition, :operator, "crosses_above")
    val1 = data[ind1]
    val2 = data[ind2]

    triggered =
      case operator do
        "crosses_above" -> is_number(val1) and is_number(val2) and val1 > val2
        "crosses_below" -> is_number(val1) and is_number(val2) and val1 < val2
        _ -> false
      end

    %{
      condition: "#{ind1} #{operator} #{ind2}",
      triggered: triggered,
      current_value: %{indicator1: val1, indicator2: val2}
    }
  end

  defp evaluate_condition(%{type: "recommendation"} = condition, data) do
    target = Map.get(condition, :target, "BUY")
    rec_value = data["Recommend.All"]
    current_rec = TradingView.classify_recommendation(rec_value)

    triggered = current_rec == String.upcase(target)

    %{
      condition: "recommendation equals #{target}",
      triggered: triggered,
      current_value: current_rec
    }
  end

  defp evaluate_condition(condition, _data) do
    %{
      condition: "unknown condition type: #{inspect(condition[:type])}",
      triggered: false,
      current_value: nil
    }
  end
end
