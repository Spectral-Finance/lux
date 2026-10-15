defmodule Lux.Trading.TechnicalAnalysisTest do
  use ExUnit.Case, async: true
  alias Lux.Trading.TechnicalAnalysis

  test "computes EMA, RSI, Bollinger Bands, and composite recommendation" do
    uptrend = Enum.map(1..25, fn i -> 100.0 + i * 2.0 end)
    {:ok, res} = TechnicalAnalysis.analyze_series(uptrend)

    assert res.ema9 > res.ema21
    assert res.rsi == 100.0
    assert res.bollinger_bands.upper > res.bollinger_bands.middle
    assert res.recommendation in [:buy, :neutral, :sell, :strong_buy, :strong_sell]
  end
end
