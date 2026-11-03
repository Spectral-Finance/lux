defmodule Lux.Lenses.TradingView.ChartDataLens do
  @moduledoc """
  Lens for retrieving historical and real-time OHLCV candlestick chart data
  from TradingView UDF (Universal Data Feed) and market data providers.

  ## Examples

      alias Lux.Lenses.TradingView.ChartDataLens

      # Fetch 1-hour candles for BTCUSDT
      {:ok, data} = ChartDataLens.focus(%{
        symbol: "BTCUSDT",
        resolution: "1h",
        limit: 100
      })
  """

  use Lux.Lens,
    name: "TradingView Chart Data Lens",
    description: "Fetches historical and streaming OHLCV chart candles for technical analysis",
    url: "https://api.binance.com/api/v3/klines",
    method: :get,
    headers: [{"content-type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Market symbol (e.g. BTCUSDT, ETHUSD, AAPL)",
          default: "BTCUSDT"
        },
        resolution: %{
          type: :string,
          description: "Bar timeframe resolution",
          enum: ["1m", "5m", "15m", "30m", "1h", "4h", "1D", "1W"],
          default: "1h"
        },
        limit: %{
          type: :integer,
          description: "Number of candlestick bars to retrieve (max 1000)",
          default: 100,
          maximum: 1000
        }
      },
      required: ["symbol"]
    }

  @doc """
  Prepares request query parameters before dispatching lens focus.
  """
  def before_focus(params) do
    symbol = Map.get(params, :symbol) || Map.get(params, "symbol", "BTCUSDT")
    clean_sym = clean_symbol(symbol)
    interval = Map.get(params, :resolution) || Map.get(params, "resolution", "1h")
    limit = Map.get(params, :limit) || Map.get(params, "limit", 100)

    params
    |> Map.put(:symbol, clean_sym)
    |> Map.put(:interval, to_binance_interval(interval))
    |> Map.put(:limit, limit)
  end

  @doc """
  Normalizes the raw API response into standardized OHLCV candle structures.
  """
  @impl true
  def after_focus(raw_klines) when is_list(raw_klines) do
    candles =
      Enum.map(raw_klines, fn
        [time, o, h, l, c, v | _rest] ->
          %{
            timestamp: to_int(time),
            open: to_float(o),
            high: to_float(h),
            low: to_float(l),
            close: to_float(c),
            volume: to_float(v)
          }

        %{} = m ->
          %{
            timestamp: to_int(m[:timestamp] || m["timestamp"] || 0),
            open: to_float(m[:open] || m["open"] || 0.0),
            high: to_float(m[:high] || m["high"] || 0.0),
            low: to_float(m[:low] || m["low"] || 0.0),
            close: to_float(m[:close] || m["close"] || 0.0),
            volume: to_float(m[:volume] || m["volume"] || 0.0)
          }
      end)

    {:ok,
     %{
       count: length(candles),
       candles: candles
     }}
  end

  def after_focus(%{"code" => code, "msg" => msg}) do
    {:error, "TradingView data provider error (#{code}): #{msg}"}
  end

  def after_focus(%{"candles" => candles} = res) when is_list(candles) do
    {:ok, res}
  end

  def after_focus(other), do: {:ok, %{raw: other}}

  # Helper: Cleans exchange prefix, e.g. "BINANCE:BTCUSDT" -> "BTCUSDT"
  defp clean_symbol(symbol) do
    case String.split(to_string(symbol), ":") do
      [_exchange, sym] -> sym
      [sym] -> sym
    end
    |> String.upcase()
  end

  defp to_binance_interval(res) do
    case String.downcase(to_string(res)) do
      "1d" -> "1d"
      "d" -> "1d"
      "1w" -> "1w"
      "w" -> "1w"
      other -> other
    end
  end

  @doc """
  Generates deterministic, continuous synthetic OHLCV candle data for offline testing and backtesting.
  """
  def generate_synthetic_candles(symbol, interval \\ "1h", count \\ 100) do
    base_price =
      case String.slice(to_string(symbol), 0, 3) do
        "BTC" -> 60_000.0
        "ETH" -> 3_000.0
        "SOL" -> 150.0
        _ -> 100.0
      end

    now = System.system_time(:millisecond)
    step_ms = interval_to_ms(interval)

    for i <- (count - 1)..0//-1 do
      t = now - i * step_ms
      wave = :math.sin(i * 0.25) * (base_price * 0.02)
      open = base_price + wave
      close = open + :math.cos(i * 0.25) * (base_price * 0.01)
      high = max(open, close) + abs(:math.sin(i * 0.5)) * (base_price * 0.005)
      low = min(open, close) - abs(:math.cos(i * 0.5)) * (base_price * 0.005)
      volume = 100.0 + abs(:math.sin(i * 0.1)) * 50.0

      %{
        timestamp: t,
        open: Float.round(open, 2),
        high: Float.round(high, 2),
        low: Float.round(low, 2),
        close: Float.round(close, 2),
        volume: Float.round(volume, 2)
      }
    end
  end

  defp interval_to_ms(interval) do
    case interval do
      "1m" -> 60 * 1000
      "5m" -> 5 * 60 * 1000
      "15m" -> 15 * 60 * 1000
      "30m" -> 30 * 60 * 1000
      "1h" -> 60 * 60 * 1000
      "4h" -> 4 * 60 * 60 * 1000
      "1D" -> 24 * 60 * 60 * 1000
      "1d" -> 24 * 60 * 60 * 1000
      "1W" -> 7 * 24 * 60 * 60 * 1000
      _ -> 60 * 60 * 1000
    end
  end

  defp to_int(v) when is_integer(v), do: v

  defp to_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp to_int(_), do: 0

  defp to_float(v) when is_float(v), do: v
  defp to_float(v) when is_integer(v), do: v * 1.0

  defp to_float(v) when is_binary(v) do
    case Float.parse(v) do
      {num, _} -> num
      :error -> 0.0
    end
  end

  defp to_float(_), do: 0.0
end
