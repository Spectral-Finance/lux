defmodule Lux.Lenses.TradingView.ChartDataLens do
  @moduledoc """
  Retrieves and normalizes multi-timeframe OHLCV chart series (`1m`, `5m`, `15m`, `1h`, `4h`, `1d`)
  for TradingView technical analysis and real-time streaming bars.
  """

  @supported_timeframes ["1m", "5m", "15m", "1h", "4h", "1d"]

  @type candle :: %{
          timestamp: integer(),
          open: float(),
          high: float(),
          low: float(),
          close: float(),
          volume: float()
        }

  @spec validate_candles([candle()], String.t()) :: {:ok, [candle()]} | {:error, atom()}
  def validate_candles(candles, timeframe \\ "1h") do
    cond do
      timeframe not in @supported_timeframes ->
        {:error, :unsupported_timeframe}

      not is_list(candles) or candles == [] ->
        {:error, :empty_candles}

      not Enum.all?(candles, fn c ->
            c.high >= c.low and c.high >= c.open and c.high >= c.close and c.low <= c.open and
              c.low <= c.close and c.volume >= 0
          end) ->
        {:error, :invalid_ohlcv_bar}

      true ->
        {:ok, Enum.sort_by(candles, & &1.timestamp)}
    end
  end
end
