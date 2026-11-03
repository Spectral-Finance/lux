defmodule Lux.Lenses.TradingView.ChartDataLensTest do
  use UnitCase, async: true

  alias Lux.Lenses.TradingView.ChartDataLens
  alias Lux.Lenses.TradingView.StreamLens

  describe "before_focus/1" do
    test "cleans exchange prefix and standardizes params" do
      params = %{symbol: "BINANCE:BTCUSDT", resolution: "1h", limit: 50}
      prepared = ChartDataLens.before_focus(params)

      assert prepared.symbol == "BTCUSDT"
      assert prepared.interval == "1h"
      assert prepared.limit == 50
    end
  end

  describe "after_focus/1" do
    test "normalizes raw klines array into candle structs" do
      raw = [
        [1_600_000_000_000, "100.5", "105.0", "99.0", "103.2", "1500.0", 1_600_003_600_000],
        [1_600_003_600_000, "103.2", "108.0", "102.0", "107.5", "1800.0", 1_600_007_200_000]
      ]

      {:ok, result} = ChartDataLens.after_focus(raw)
      assert result.count == 2
      [c1, c2] = result.candles
      assert c1.timestamp == 1_600_000_000_000
      assert c1.open == 100.5
      assert c1.high == 105.0
      assert c1.low == 99.0
      assert c1.close == 103.2
      assert c1.volume == 1500.0
      assert c2.close == 107.5
    end

    test "handles error response maps gracefully" do
      err_res = %{"code" => -1121, "msg" => "Invalid symbol."}
      assert {:error, msg} = ChartDataLens.after_focus(err_res)
      assert msg =~ "Invalid symbol"
    end
  end

  describe "generate_synthetic_candles/3" do
    test "produces continuous valid OHLCV candles" do
      candles = ChartDataLens.generate_synthetic_candles("ETHUSDT", "15m", 25)
      assert length(candles) == 25

      first = hd(candles)
      assert is_integer(first.timestamp)
      assert is_float(first.open)
      assert is_float(first.high)
      assert is_float(first.low)
      assert is_float(first.close)
      assert is_float(first.volume)
      assert first.high >= first.low
      assert first.high >= first.open
      assert first.high >= first.close
    end
  end

  describe "StreamLens pub/sub" do
    test "subscribes process and delivers real-time bar events" do
      {:ok, stream_pid} = StreamLens.start_link(name: :test_stream_lens)

      :ok = StreamLens.subscribe(stream_pid, "BTCUSDT")

      bar = %{timestamp: 1_700_000_000, open: 65_000, close: 65_500, volume: 10}
      :ok = StreamLens.push_bar(stream_pid, "BTCUSDT", bar)

      assert_receive {:tradingview_bar, "BTCUSDT", ^bar}, 500

      :ok = StreamLens.unsubscribe(stream_pid, "BTCUSDT")
      :ok = StreamLens.push_bar(stream_pid, "BTCUSDT", bar)

      refute_receive {:tradingview_bar, "BTCUSDT", _}, 100
    end
  end
end
