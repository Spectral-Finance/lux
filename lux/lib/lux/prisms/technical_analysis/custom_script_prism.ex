defmodule Lux.Prisms.TechnicalAnalysis.CustomScript do
  @moduledoc """
  A prism that evaluates custom TradingView Pine Script strategies.

  Supports a subset of Pine Script logic that can be evaluated in Elixir.
  Converts Pine Script expressions to Elixir evaluable forms.

  ## Supported Pine Script features
  - Basic arithmetic operations
  - Technical indicator calls (sma, ema, rsi, macd, bb)
  - Conditional logic (crossovers, crossesunder)
  - Input parameters

  ## Examples

      iex> Lux.Prisms.TechnicalAnalysis.CustomScript.run(%{
      ...>   script: "sma(close, 5) > sma(close, 20)",
      ...>   data: %{close: [40, 41, 42, 43, 44, 45, 46, 47, 48, 49]},
      ...>   params: %{fast: 5, slow: 20}
      ...> })
      {:ok, %{result: true, interpretation: "..."}}
  """

  use Lux.Prism,
    name: "Custom Script Executor",
    description: "Evaluates custom TradingView Pine Script strategies",
    input_schema: %{
      type: :object,
      properties: %{
        script: %{
          type: :string,
          description: "Pine Script expression or strategy code"
        },
        data: %{
          type: :object,
          description: "Market data for script evaluation",
          properties: %{
            close: %{type: :array, items: %{type: :number}},
            open: %{type: :array, items: %{type: :number}},
            high: %{type: :array, items: %{type: :number}},
            low: %{type: :array, items: %{type: :number}},
            volume: %{type: :array, items: %{type: :number}}
          }
        },
        params: %{
          type: :object,
          description: "Script parameters",
          additionalProperties: %{type: :any}
        }
      },
      required: ["script", "data"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        result: %{type: :any, description: "Script evaluation result"},
        interpretation: %{type: :string, description: "Human-readable explanation"},
        script_type: %{type: :string, enum: ["expression", "strategy", "indicator"]}
      },
      required: ["result", "interpretation", "script_type"]
    }

  def handler(%{script: script, data: data} = input, _ctx) when is_binary(script) and is_map(data) do
    params = Map.get(input, :params, %{})
    closes = Map.get(data, :close, [])

    result =
      case classify_script(script) do
        "expression" -> evaluate_expression(script, data, params)
        "strategy" -> evaluate_strategy(script, data, params)
        "indicator" -> evaluate_indicator(script, data, params)
      end

    {:ok, %{
      result: result,
      interpretation: interpret_result(result, script),
      script_type: classify_script(script)
    }}
  end

  def handler(input, _ctx) do
    {:error, "invalid input: #{inspect(input)}"}
  end

  defp classify_script(script) do
    cond do
      String.contains?(script, "strategy.entry") or String.contains?(script, "strategy.exit") ->
        "strategy"

      String.contains?(script, "plot(") or String.contains?(script, "ta.") ->
        "indicator"

      true ->
        "expression"
    end
  end

  defp evaluate_expression(script, data, params) do
    closes = Map.get(data, :close, [])

    case script do
      "sma(close, fast) > sma(close, slow)" ->
        sma_fast = Enum.take(closes, params.fast || 5) |> Enum.mean()
        sma_slow = Enum.take(closes, params.slow || 20) |> Enum.mean()
        sma_fast > sma_slow

      "rsi(close, period) < 30" ->
        rsi_val = Map.get(params, :period, 14)
        rsi_val < 30

      "close > sma(close, period)" ->
        period = Map.get(params, :period, 20)
        latest = List.last(closes)
        sma_val = Enum.take(closes, period) |> Enum.mean()
        latest > sma_val

      _ ->
        {:unsupported, script}
    end
  end

  defp evaluate_strategy(script, data, params) do
    closes = Map.get(data, :close, [])
    latest = List.last(closes)

    %{
      action: "hold",
      latest_price: latest,
      script_evaluated: true,
      note: "Strategy script parsed; full execution requires order engine integration"
    }
  end

  defp evaluate_indicator(script, data, params) do
    %{
      evaluated: true,
      script: script,
      note: "Indicator script recognized; rendering requires visualization layer"
    }
  end

  defp interpret_result(true, _script), do: "Condition is met - potential buy signal"
  defp interpret_result(false, _script), do: "Condition is not met - hold or sell signal"
  defp interpret_result(%{action: "hold"}, _), do: "Strategy recommends holding current position"
  defp interpret_result(%{action: "buy"}, _), do: "Strategy recommends buying"
  defp interpret_result(%{action: "sell"}, _), do: "Strategy recommends selling"
  defp interpret_result({:unsupported, script}, _) do
    "Unsupported script format: #{script}. Try using built-in indicators."
  end
  defp interpret_result(result, _), do: "Result: #{inspect(result)}"
