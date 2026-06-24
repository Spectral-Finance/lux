defmodule Lux.Prisms.TradingView.GetIndicatorsPrism do
  @moduledoc """
  A prism for computing technical analysis indicators on OHLCV price data.

  Calculates common indicators: SMA, EMA, RSI, MACD, Bollinger Bands,
  and Stochastic Oscillator using pure Elixir computation.

  ## Examples

      iex> Lux.Prisms.TradingView.GetIndicatorsPrism.handler(%{
      ...>   prices: [100.0, 102.0, 98.0, 105.0, 103.0, 107.0, 110.0],
      ...>   indicator: "rsi",
      ...>   period: 14
      ...> }, %{name: "Agent"})
      {:ok, %{indicator: "rsi", period: 14, values: [65.3], current: 65.3}}
  """

  use Lux.Prism,
    name: "TradingView Get Indicators",
    description: "Computes technical indicators (SMA, EMA, RSI, MACD, BB, Stoch) on price data",
    input_schema: %{
      type: :object,
      properties: %{
        prices: %{
          type: :array,
          description: "List of closing prices (chronological order)",
          items: %{type: :number},
          minItems: 2
        },
        indicator: %{
          type: :string,
          description: "Indicator to compute",
          enum: ["sma", "ema", "rsi", "macd", "bollinger", "stochastic"]
        },
        period: %{
          type: :integer,
          description: "Indicator period (default varies by indicator)",
          default: 14
        },
        fast_period: %{type: :integer, description: "Fast period for MACD (default: 12)"},
        slow_period: %{type: :integer, description: "Slow period for MACD (default: 26)"},
        signal_period: %{type: :integer, description: "Signal period for MACD (default: 9)"},
        std_dev: %{type: :number, description: "Std deviation multiplier for Bollinger Bands (default: 2.0)"}
      },
      required: ["prices", "indicator"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        indicator: %{type: :string},
        period: %{type: :integer},
        values: %{type: :array, items: %{type: :number}},
        current: %{type: :number, description: "Most recent value"},
        signal: %{type: :number, description: "Signal line (MACD)"},
        upper: %{type: :number, description: "Upper band (Bollinger)"},
        lower: %{type: :number, description: "Lower band (Bollinger)"},
        middle: %{type: :number, description: "Middle band (Bollinger)"},
        k: %{type: :number, description: "Stochastic %K"},
        d: %{type: :number, description: "Stochastic %D"}
      },
      required: ["indicator", "current"]
    }

  require Logger

  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    prices = params.prices
    indicator = params.indicator
    period = Map.get(params, :period, default_period(indicator))

    Logger.info("Agent #{agent_name} computing #{indicator}(#{period}) on #{length(prices)} prices")

    result = compute_indicator(indicator, prices, period, params)
    Logger.info("#{indicator} computed: current=#{result[:current]}")
    {:ok, result}
  rescue
    e -> {:error, "Computation error: #{Exception.message(e)}"}
  end

  defp default_period("rsi"), do: 14
  defp default_period("macd"), do: 12
  defp default_period("stochastic"), do: 14
  defp default_period("bollinger"), do: 20
  defp default_period(_), do: 14

  defp compute_indicator("sma", prices, period, _params) do
    values = sma(prices, period)
    %{indicator: "sma", period: period, values: values, current: List.last(values)}
  end

  defp compute_indicator("ema", prices, period, _params) do
    values = ema(prices, period)
    %{indicator: "ema", period: period, values: values, current: List.last(values)}
  end

  defp compute_indicator("rsi", prices, period, _params) do
    values = rsi(prices, period)
    %{indicator: "rsi", period: period, values: values, current: List.last(values)}
  end

  defp compute_indicator("macd", prices, _period, params) do
    fast = Map.get(params, :fast_period, 12)
    slow = Map.get(params, :slow_period, 26)
    signal_p = Map.get(params, :signal_period, 9)
    {macd_line, signal_line, histogram} = macd(prices, fast, slow, signal_p)
    %{
      indicator: "macd",
      period: fast,
      values: macd_line,
      current: List.last(macd_line) || 0,
      signal: List.last(signal_line) || 0,
      histogram: List.last(histogram) || 0
    }
  end

  defp compute_indicator("bollinger", prices, period, params) do
    std_dev = Map.get(params, :std_dev, 2.0)
    {upper, middle, lower} = bollinger_bands(prices, period, std_dev)
    %{
      indicator: "bollinger",
      period: period,
      values: middle,
      current: List.last(middle) || 0,
      upper: List.last(upper) || 0,
      lower: List.last(lower) || 0,
      middle: List.last(middle) || 0
    }
  end

  defp compute_indicator("stochastic", prices, period, params) do
    smooth_k = Map.get(params, :smooth_k, 3)
    smooth_d = Map.get(params, :smooth_d, 3)
    {k, d} = stochastic(prices, period, smooth_k, smooth_d)
    %{
      indicator: "stochastic",
      period: period,
      values: k,
      current: List.last(k) || 0,
      k: List.last(k) || 0,
      d: List.last(d) || 0
    }
  end

  # --- Computation Functions ---

  defp sma(prices, period) do
    prices
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(fn chunk -> Enum.sum(chunk) / period end)
  end

  defp ema(prices, period) do
    k = 2.0 / (period + 1)
    [first | rest] = prices
    init = Enum.take(prices, period)
    initial_ema = Enum.sum(init) / length(init)
    remaining = Enum.drop(prices, period)
    Enum.reduce(remaining, [initial_ema], fn price, [prev | _] = acc ->
      ema_val = price * k + prev * (1 - k)
      [ema_val | acc]
    end)
    |> Enum.reverse()
  rescue
    _ -> []
  end

  defp rsi(prices, period) do
    changes = prices |> Enum.chunk_every(2, 1, :discard) |> Enum.map(fn [a, b] -> b - a end)
    gains = Enum.map(changes, fn c -> max(c, 0) end)
    losses = Enum.map(changes, fn c -> max(-c, 0) end)

    avg_gain = Enum.take(gains, period) |> Enum.sum() |> Kernel./(period)
    avg_loss = Enum.take(losses, period) |> Enum.sum() |> Kernel./(period)

    {_, _, rsi_values} = Enum.slice(gains, period..-1//1)
    |> Enum.zip(Enum.slice(losses, period..-1//1))
    |> Enum.reduce({avg_gain, avg_loss, []}, fn {g, l}, {ag, al, vals} ->
      new_ag = (ag * (period - 1) + g) / period
      new_al = (al * (period - 1) + l) / period
      rs = if new_al == 0, do: 100.0, else: new_ag / new_al
      rsi_val = 100 - 100 / (1 + rs)
      {new_ag, new_al, [rsi_val | vals]}
    end)

    Enum.reverse(rsi_values)
  rescue
    _ -> []
  end

  defp macd(prices, fast, slow, signal_p) do
    fast_ema = ema(prices, fast)
    slow_ema = ema(prices, slow)
    min_len = min(length(fast_ema), length(slow_ema))
    macd_line = Enum.zip(
      Enum.take(fast_ema, -min_len),
      Enum.take(slow_ema, -min_len)
    ) |> Enum.map(fn {f, s} -> f - s end)
    signal_line = ema(macd_line, signal_p)
    min_len2 = min(length(macd_line), length(signal_line))
    histogram = Enum.zip(
      Enum.take(macd_line, -min_len2),
      Enum.take(signal_line, -min_len2)
    ) |> Enum.map(fn {m, s} -> m - s end)
    {macd_line, signal_line, histogram}
  rescue
    _ -> {[], [], []}
  end

  defp bollinger_bands(prices, period, std_dev_mult) do
    middle = sma(prices, period)
    rolling_std = prices
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(fn chunk ->
      mean = Enum.sum(chunk) / period
      variance = chunk |> Enum.map(fn x -> (x - mean) * (x - mean) end) |> Enum.sum() |> Kernel./(period)
      :math.sqrt(variance)
    end)
    upper = Enum.zip(middle, rolling_std) |> Enum.map(fn {m, s} -> m + std_dev_mult * s end)
    lower = Enum.zip(middle, rolling_std) |> Enum.map(fn {m, s} -> m - std_dev_mult * s end)
    {upper, middle, lower}
  rescue
    _ -> {[], [], []}
  end

  defp stochastic(prices, period, smooth_k, smooth_d) do
    k_raw = prices
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(fn chunk ->
      low = Enum.min(chunk)
      high = Enum.max(chunk)
      close = List.last(chunk)
      if high == low, do: 50.0, else: (close - low) / (high - low) * 100
    end)

    k = sma(k_raw, smooth_k)
    d = sma(k, smooth_d)
    {k, d}
  rescue
    _ -> {[], []}
  end
end
