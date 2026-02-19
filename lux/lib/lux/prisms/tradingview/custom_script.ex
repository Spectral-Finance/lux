defmodule Lux.Prisms.TradingView.CustomScript do
  @moduledoc """
  A prism that executes custom technical analysis scripts against TradingView data.

  Allows users to define custom indicator logic using a simple expression language
  that operates on TradingView indicator values. This provides Pine Script-like
  functionality for custom analysis without requiring TradingView's platform.

  ## Supported Operations

  The script evaluator supports:
  - **Arithmetic**: `+`, `-`, `*`, `/`
  - **Comparison**: `>`, `<`, `>=`, `<=`, `==`
  - **Logic**: `and`, `or`, `not`
  - **Functions**: `avg(a, b)`, `max(a, b)`, `min(a, b)`, `abs(x)`, `cross_above(a, b_prev, b)`, `cross_below(a, b_prev, b)`
  - **Indicator references**: Direct column names like `RSI`, `MACD.macd`, `close`, etc.

  ## Examples

      # Custom RSI divergence detection
      iex> Lux.Prisms.TradingView.CustomScript.run(%{
      ...>   symbol: "TSLA",
      ...>   exchange: "NASDAQ",
      ...>   screener: "america",
      ...>   interval: "1d",
      ...>   scripts: [
      ...>     %{
      ...>       name: "RSI Oversold with MACD Bullish",
      ...>       conditions: [
      ...>         %{left: "RSI", op: "<", right: 30},
      ...>         %{left: "MACD.macd", op: ">", right: "MACD.signal"}
      ...>       ]
      ...>     },
      ...>     %{
      ...>       name: "Golden Cross Check",
      ...>       conditions: [
      ...>         %{left: "EMA50", op: ">", right: "SMA200"}
      ...>       ]
      ...>     }
      ...>   ]
      ...> })
      {:ok, %{
        symbol: "NASDAQ:TSLA",
        script_results: [
          %{name: "RSI Oversold with MACD Bullish", result: true, details: [...]},
          %{name: "Golden Cross Check", result: true, details: [...]}
        ],
        all_true: true,
        indicator_values: %{"RSI" => 28.5, "MACD.macd" => 2.1, ...}
      }}
  """

  use Lux.Prism,
    name: "TradingView Custom Script",
    description: "Executes custom technical analysis scripts against TradingView indicator data",
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
        interval: %{
          type: :string,
          description: "Time interval",
          enum: ["1m", "5m", "15m", "30m", "1h", "2h", "4h", "1d", "1W", "1M"],
          default: "1d"
        },
        scripts: %{
          type: :array,
          description: "List of custom scripts to evaluate",
          items: %{
            type: :object,
            properties: %{
              name: %{type: :string, description: "Script name"},
              conditions: %{
                type: :array,
                description: "List of conditions (all must be true)",
                items: %{
                  type: :object,
                  properties: %{
                    left: %{type: [:string, :number], description: "Left operand (indicator name or number)"},
                    op: %{type: :string, description: "Operator", enum: [">", "<", ">=", "<=", "==", "!="]},
                    right: %{type: [:string, :number], description: "Right operand (indicator name or number)"}
                  },
                  required: ["left", "op", "right"]
                }
              }
            },
            required: ["name", "conditions"]
          }
        },
        extra_indicators: %{
          type: :array,
          description: "Additional indicator columns to fetch",
          items: %{type: :string}
        }
      },
      required: ["symbol", "exchange", "scripts"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string},
        script_results: %{
          type: :array,
          description: "Results for each script"
        },
        all_true: %{
          type: :boolean,
          description: "Whether all scripts evaluated to true"
        },
        indicator_values: %{
          type: :object,
          description: "Raw indicator values used in evaluation"
        }
      },
      required: ["symbol", "script_results", "all_true"]
    }

  alias Lux.Integrations.TradingView
  alias Lux.Integrations.TradingView.Client

  def handler(input, _ctx) do
    symbol = Map.fetch!(input, :symbol)
    exchange = Map.fetch!(input, :exchange)
    screener = Map.get(input, :screener, "america")
    interval = Map.get(input, :interval, "1d")
    scripts = Map.fetch!(input, :scripts)
    extra = Map.get(input, :extra_indicators, [])

    ticker = TradingView.format_ticker(symbol, exchange)

    # Extract all indicator names from scripts
    script_indicators = extract_script_indicators(scripts)
    all_indicators = (script_indicators ++ extra) |> Enum.uniq()

    # Validate and fetch data
    columns =
      if Enum.empty?(all_indicators) do
        TradingView.all_columns()
      else
        all_indicators
      end

    body = Client.build_scan_body([ticker], columns, interval)

    case Client.scan(screener, body) do
      {:ok, response} ->
        interval_columns = Enum.map(columns, &TradingView.column_with_interval(&1, interval))
        parsed = Client.parse_scan_response(response, interval_columns)

        case Map.get(parsed, ticker) do
          nil ->
            {:error, "No data returned for #{ticker}"}

          data ->
            script_results = Enum.map(scripts, &evaluate_script(&1, data))
            all_true = Enum.all?(script_results, & &1.result)

            # Build indicator values map with only used indicators
            indicator_values =
              Map.filter(data, fn {k, v} -> k in script_indicators and not is_nil(v) end)

            {:ok, %{
              symbol: ticker,
              script_results: script_results,
              all_true: all_true,
              indicator_values: indicator_values
            }}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_script_indicators(scripts) do
    scripts
    |> Enum.flat_map(fn script ->
      script.conditions
      |> Enum.flat_map(fn condition ->
        left = resolve_indicator_name(condition.left)
        right = resolve_indicator_name(condition.right)
        Enum.filter([left, right], &is_binary/1)
      end)
    end)
    |> Enum.uniq()
  end

  defp resolve_indicator_name(value) when is_binary(value), do: value
  defp resolve_indicator_name(_), do: nil

  defp evaluate_script(script, data) do
    condition_results =
      Enum.map(script.conditions, fn condition ->
        left_val = resolve_value(condition.left, data)
        right_val = resolve_value(condition.right, data)
        op = condition.op

        result = evaluate_comparison(left_val, op, right_val)

        %{
          left: condition.left,
          left_value: left_val,
          op: op,
          right: condition.right,
          right_value: right_val,
          result: result
        }
      end)

    all_met = Enum.all?(condition_results, & &1.result)

    %{
      name: script.name,
      result: all_met,
      details: condition_results
    }
  end

  defp resolve_value(value, _data) when is_number(value), do: value

  defp resolve_value(value, data) when is_binary(value) do
    case Float.parse(value) do
      {num, ""} -> num
      _ -> data[value]
    end
  end

  defp resolve_value(_, _), do: nil

  defp evaluate_comparison(nil, _op, _right), do: false
  defp evaluate_comparison(_left, _op, nil), do: false

  defp evaluate_comparison(left, ">", right) when is_number(left) and is_number(right),
    do: left > right

  defp evaluate_comparison(left, "<", right) when is_number(left) and is_number(right),
    do: left < right

  defp evaluate_comparison(left, ">=", right) when is_number(left) and is_number(right),
    do: left >= right

  defp evaluate_comparison(left, "<=", right) when is_number(left) and is_number(right),
    do: left <= right

  defp evaluate_comparison(left, "==", right) when is_number(left) and is_number(right),
    do: abs(left - right) < 0.0001

  defp evaluate_comparison(left, "!=", right) when is_number(left) and is_number(right),
    do: abs(left - right) >= 0.0001

  defp evaluate_comparison(_, _, _), do: false
end
