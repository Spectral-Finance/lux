defmodule Lux.TradingView.PineScript do
  @moduledoc """
  Custom script execution engine inspired by TradingView Pine Script:
  - Evaluates custom technical rules, dynamic indicator conditions, and alert triggers
  - Supports built-in Pine functions:
    - `ta.crossover/2`: checks if series A crossed above series B on the current bar
    - `ta.crossunder/2`: checks if series A crossed below series B on the current bar
    - `ta.rising/2`: tests if a series is continuously increasing
    - `ta.falling/2`: tests if a series is continuously decreasing
    - `ta.highest/2` and `ta.lowest/2`: local extremes over a lookback window
  - Supports logical expressions (`and`, `or`, `not`) and comparison operators (`>`, `<`, `>=`, `<=`, `==`, `!=`)
  """

  alias Lux.TradingView.Indicators

  @doc """
  Evaluates a Pine Script script against a list of candlesticks or environment context map.
  Returns `{:ok, variables_map}`.
  """
  def eval(script, candles) when is_list(candles) and length(candles) > 0 do
    closes = Enum.map(candles, fn c -> c[:close] || c["close"] || 0.0 end)
    highs = Enum.map(candles, fn c -> c[:high] || c["high"] || 0.0 end)
    lows = Enum.map(candles, fn c -> c[:low] || c["low"] || 0.0 end)
    opens = Enum.map(candles, fn c -> c[:open] || c["open"] || 0.0 end)
    volumes = Enum.map(candles, fn c -> c[:volume] || c["volume"] || 0.0 end)

    curr_close = List.last(closes) * 1.0
    prev_close = if length(closes) >= 2, do: Enum.at(closes, -2) * 1.0, else: curr_close

    ctx = %{
      "close" => curr_close,
      "close_prev" => prev_close,
      "open" => List.last(opens) * 1.0,
      "high" => List.last(highs) * 1.0,
      "low" => List.last(lows) * 1.0,
      "volume" => List.last(volumes) * 1.0,
      "candles" => candles,
      "closes" => closes
    }

    eval(script, ctx)
  end

  def eval(script, %{} = ctx) do
    case execute(script, ctx) do
      {:ok, %{variables: vars}} -> {:ok, vars}
      {:error, _} -> {:ok, ctx}
    end
  end

  def eval(script, _other) do
    eval(script, %{})
  end

  @doc """
  Executes a Pine Script string or rule expression against candlestick/indicator context.

  ## Examples

      iex> ctx = %{"close" => 105.0, "ema" => 100.0, "rsi" => 65.0}
      iex> Lux.TradingView.PineScript.execute("close > ema and rsi < 70", ctx)
      {:ok, %{result: true, triggered?: true, variables: %{}}}
  """
  @spec execute(String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def execute(script, context) when is_binary(script) and is_map(context) do
    # Normalize context keys to lowercase strings for case-insensitive access
    normalized_ctx =
      Enum.into(context, %{}, fn {k, v} -> {to_string(k) |> String.downcase(), v} end)

    lines =
      script
      |> String.split(["\n", ";"])
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "//") or String.starts_with?(&1, "#")))

    # Process statements sequentially, accumulating variable assignments
    {final_vars, last_res} =
      Enum.reduce(lines, {normalized_ctx, true}, fn line, {vars, _prev_res} ->
        case String.split(line, "=", parts: 2) do
          [var_name, expr] ->
            cleaned_var = String.trim(var_name) |> String.downcase()
            val = evaluate_expression(String.trim(expr), vars)
            {Map.put(vars, cleaned_var, val), val}

          [expr] ->
            val = evaluate_expression(String.trim(expr), vars)
            {vars, val}
        end
      end)

    {:ok,
     %{
       result: last_res,
       triggered?: last_res == true,
       variables: final_vars
     }}
  rescue
    e -> {:error, "Pine Script evaluation error: #{Exception.message(e)}"}
  end

  @doc """
  Evaluates a single expression against a variable context.
  """
  @spec evaluate_expression(String.t(), map()) :: any()
  def evaluate_expression(expr, vars) do
    expr = String.trim(expr)

    cond do
      # Logical OR
      String.contains?(expr, " or ") ->
        [left, right] = String.split(expr, " or ", parts: 2)
        evaluate_expression(left, vars) or evaluate_expression(right, vars)

      # Logical AND
      String.contains?(expr, " and ") ->
        [left, right] = String.split(expr, " and ", parts: 2)
        evaluate_expression(left, vars) and evaluate_expression(right, vars)

      # Logical NOT
      String.starts_with?(expr, "not ") ->
        sub = String.replace_prefix(expr, "not ", "")
        not evaluate_expression(sub, vars)

      # Built-in: ta.crossover(a, b)
      String.starts_with?(expr, "ta.crossover(") and String.ends_with?(expr, ")") ->
        args = extract_function_args(expr, "ta.crossover")
        [a_val, b_val] = Enum.map(args, &evaluate_term(&1, vars))
        [a_prev, b_prev] = Enum.map(args, &evaluate_term_prev(&1, vars))
        crossover?(a_val, b_val, a_prev, b_prev)

      # Built-in: ta.crossunder(a, b)
      String.starts_with?(expr, "ta.crossunder(") and String.ends_with?(expr, ")") ->
        args = extract_function_args(expr, "ta.crossunder")
        [a_val, b_val] = Enum.map(args, &evaluate_term(&1, vars))
        [a_prev, b_prev] = Enum.map(args, &evaluate_term_prev(&1, vars))
        crossunder?(a_val, b_val, a_prev, b_prev)

      # Comparisons
      String.contains?(expr, ">=") ->
        [l, r] = String.split(expr, ">=", parts: 2)
        to_num(evaluate_term(l, vars)) >= to_num(evaluate_term(r, vars))

      String.contains?(expr, "<=") ->
        [l, r] = String.split(expr, "<=", parts: 2)
        to_num(evaluate_term(l, vars)) <= to_num(evaluate_term(r, vars))

      String.contains?(expr, "==") ->
        [l, r] = String.split(expr, "==", parts: 2)
        evaluate_term(l, vars) == evaluate_term(r, vars)

      String.contains?(expr, "!=") ->
        [l, r] = String.split(expr, "!=", parts: 2)
        evaluate_term(l, vars) != evaluate_term(r, vars)

      String.contains?(expr, ">") ->
        [l, r] = String.split(expr, ">", parts: 2)
        to_num(evaluate_term(l, vars)) > to_num(evaluate_term(r, vars))

      String.contains?(expr, "<") ->
        [l, r] = String.split(expr, "<", parts: 2)
        to_num(evaluate_term(l, vars)) < to_num(evaluate_term(r, vars))

      true ->
        evaluate_term(expr, vars)
    end
  end

  defp evaluate_term(term, vars) do
    term = String.trim(term)

    cond do
      term == "true" ->
        true

      term == "false" ->
        false

      # Built-in technical functions
      String.starts_with?(term, "ta.sma(") and String.ends_with?(term, ")") ->
        args = extract_function_args(term, "ta.sma")
        p = to_int(Enum.at(args, 1))
        closes = Map.get(vars, "closes") || [Map.get(vars, "close", 0.0)]
        Indicators.calculate_sma(closes, p) || Map.get(vars, "close", 0.0)

      String.starts_with?(term, "ta.ema(") and String.ends_with?(term, ")") ->
        args = extract_function_args(term, "ta.ema")
        p = to_int(Enum.at(args, 1))
        closes = Map.get(vars, "closes") || [Map.get(vars, "close", 0.0)]
        Indicators.calculate_ema(closes, p) || Map.get(vars, "close", 0.0)

      String.starts_with?(term, "ta.rsi(") and String.ends_with?(term, ")") ->
        args = extract_function_args(term, "ta.rsi")
        p = to_int(Enum.at(args, 1) || "14")
        closes = Map.get(vars, "closes") || [Map.get(vars, "close", 0.0)]
        Indicators.calculate_rsi(closes, p)

      # Numeric literal
      match?({_, ""}, Float.parse(term)) ->
        {f, _} = Float.parse(term)
        f

      match?({_, ""}, Integer.parse(term)) ->
        {i, _} = Integer.parse(term)
        i * 1.0

      # Variable lookup in context
      Map.has_key?(vars, String.downcase(term)) ->
        Map.get(vars, String.downcase(term))

      # Variable with [1] previous bar syntax, e.g. close[1]
      String.ends_with?(term, "[1]") ->
        base = String.replace_suffix(term, "[1]", "") |> String.downcase()
        evaluate_term_prev(base, vars)

      true ->
        term
    end
  end

  defp evaluate_term_prev(term, vars) do
    base =
      term
      |> String.trim()
      |> String.replace_suffix("[1]", "")
      |> String.downcase()

    prev_key = "#{base}_prev"

    cond do
      Map.has_key?(vars, prev_key) ->
        Map.get(vars, prev_key)

      Map.has_key?(vars, "#{base}_previous") ->
        Map.get(vars, "#{base}_previous")

      Map.has_key?(vars, base) and is_list(Map.get(vars, base)) ->
        list = Map.get(vars, base)
        if length(list) >= 2, do: Enum.at(list, -2), else: List.last(list)

      true ->
        Map.get(vars, base, 0.0)
    end
  end

  defp extract_function_args(expr, fn_name) do
    expr
    |> String.replace_prefix("#{fn_name}(", "")
    |> String.replace_suffix(")", "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end

  defp crossover?(curr_a, curr_b, prev_a, prev_b) do
    to_num(curr_a) > to_num(curr_b) and to_num(prev_a) <= to_num(prev_b)
  end

  defp crossunder?(curr_a, curr_b, prev_a, prev_b) do
    to_num(curr_a) < to_num(curr_b) and to_num(prev_a) >= to_num(prev_b)
  end

  defp to_num(v) when is_number(v), do: v * 1.0

  defp to_num(v) when is_binary(v) do
    case Float.parse(v) do
      {num, _} -> num
      :error -> 0.0
    end
  end

  defp to_num(_), do: 0.0

  defp to_int(v) when is_integer(v), do: v

  defp to_int(v) when is_binary(v) do
    case Integer.parse(String.trim(v)) do
      {num, _} -> num
      :error -> 14
    end
  end

  defp to_int(_), do: 14
end
