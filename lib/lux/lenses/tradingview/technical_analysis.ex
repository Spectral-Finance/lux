defmodule Lux.Lenses.TradingView.TechnicalAnalysis do
  @moduledoc """
  Calculates Technical Indicators purely in Elixir and acts as a lens.
  """
  use Lux.Lens,
    name: "TradingView Technical Analysis",
    description: "Computes technical indicators such as RSI, MACD, SMA, EMA, and Bollinger Bands.",
    url: "local://technical_analysis",
    method: :post,
    headers: [],
    schema: %{
      type: :object,
      properties: %{
        prices: %{type: :array, items: %{type: :number}},
        indicator: %{type: :string, enum: ["sma", "ema", "rsi", "macd", "bbands"]},
        period: %{type: :integer}
      },
      required: ["prices", "indicator"]
    }

  def before_focus(params) do
    {:ok, Map.put_new(params, :period, 14)}
  end

  def focus(params) do
    prices = Map.get(params, :prices, [])
    period = Map.get(params, :period, 14)
    indicator = Map.get(params, :indicator, "sma")

    result =
      case indicator do
        "sma" -> sma(prices, period)
        "ema" -> ema(prices, period)
        "rsi" -> rsi(prices, period)
        "macd" -> macd(prices)
        "bbands" -> bbands(prices, period)
        _ -> {:error, "Unknown indicator"}
      end

    {:ok, result}
  end

  def after_focus({:ok, result}), do: {:ok, %{status: :success, data: result}}
  def after_focus(error), do: error

  def sma(prices, period) when length(prices) < period, do: []
  def sma(prices, period) do
    prices
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(fn chunk -> Enum.sum(chunk) / period end)
  end

  def ema(prices, period) when length(prices) < period, do: []
  def ema(prices, period) do
    k = 2 / (period + 1)
    {sma_chunk, rest_prices} = Enum.split(prices, period)
    initial_ema = Enum.sum(sma_chunk) / period
    
    Enum.scan(rest_prices, initial_ema, fn price, prev_ema ->
      (price - prev_ema) * k + prev_ema
    end)
    |> then(fn emas -> [initial_ema | emas] end)
  end

  def rsi(prices, period) when length(prices) <= period, do: []
  def rsi(prices, period) do
    changes =
      prices
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [prev, curr] -> curr - prev end)

    {gains, losses} =
      Enum.split(changes, period)
      |> elem(0)
      |> Enum.reduce({0, 0}, fn
        change, {g, l} when change > 0 -> {g + change, l}
        change, {g, l} when change < 0 -> {g, l + abs(change)}
        _, acc -> acc
      end)

    avg_gain = gains / period
    avg_loss = losses / period

    initial_rsi = if avg_loss == 0, do: 100.0, else: 100.0 - (100.0 / (1.0 + (avg_gain / avg_loss)))

    rest_changes = Enum.drop(changes, period)

    {rsis, _, _} = Enum.reduce(rest_changes, {[initial_rsi], avg_gain, avg_loss}, fn change, {acc, prev_ag, prev_al} ->
      {g, l} = if change > 0, do: {change, 0}, else: {0, abs(change)}
      ag = (prev_ag * (period - 1) + g) / period
      al = (prev_al * (period - 1) + l) / period
      rsi = if al == 0, do: 100.0, else: 100.0 - (100.0 / (1.0 + (ag / al)))
      {[rsi | acc], ag, al}
    end)
    
    Enum.reverse(rsis)
  end

  def macd(prices) do
    ema12 = ema(prices, 12)
    ema26 = ema(prices, 26)
    
    len_diff = length(ema12) - length(ema26)
    if len_diff < 0 do
      %{macd: [], signal: [], histogram: []}
    else
      ema12_aligned = Enum.drop(ema12, len_diff)
      macd_line = Enum.zip_with(ema12_aligned, ema26, fn a, b -> a - b end)
      signal_line = ema(macd_line, 9)
      
      len_diff_sig = length(macd_line) - length(signal_line)
      macd_aligned = Enum.drop(macd_line, len_diff_sig)
      
      histogram = Enum.zip_with(macd_aligned, signal_line, fn m, s -> m - s end)
      %{macd: macd_aligned, signal: signal_line, histogram: histogram}
    end
  end

  def bbands(prices, period) when length(prices) < period, do: []
  def bbands(prices, period) do
    prices
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(fn chunk ->
      sma = Enum.sum(chunk) / period
      variance = Enum.map(chunk, fn p -> :math.pow(p - sma, 2) end) |> Enum.sum() |> Kernel./(period)
      stddev = :math.sqrt(variance)
      %{
        upper: sma + 2 * stddev,
        middle: sma,
        lower: sma - 2 * stddev
      }
    end)
  end
end
