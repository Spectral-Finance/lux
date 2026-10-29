defmodule Lux.Lenses.TradingView.ChartDataTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.TradingView.ChartData

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "fetches OHLCV data with pivot points" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"

        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [
                253.80, 248.50, 255.30, 247.10,  # close, open, high, low
                52_340_000, 2.13, 5.30,            # volume, change, change_abs
                240.10, 243.60, 247.10, 250.60,   # S3, S2, S1, Middle
                254.10, 257.60, 261.10            # R1, R2, R3
              ]
            }
          ]
        })
      end)

      assert {:ok, result} =
               ChartData.focus(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 screener: "america",
                 interval: "1d"
               })

      assert result.symbol == "NASDAQ:TSLA"
      assert result.open == 248.50
      assert result.high == 255.30
      assert result.low == 247.10
      assert result.close == 253.80
      assert result.volume == 52_340_000
      assert result.change == 2.13
      assert result.change_abs == 5.30

      # Verify pivot points
      assert result.pivot_points.s3 == 240.10
      assert result.pivot_points.s2 == 243.60
      assert result.pivot_points.s1 == 247.10
      assert result.pivot_points.middle == 250.60
      assert result.pivot_points.r1 == 254.10
      assert result.pivot_points.r2 == 257.60
      assert result.pivot_points.r3 == 261.10
    end

    test "fetches OHLCV data without pivot points" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [253.80, 248.50, 255.30, 247.10, 52_340_000, 2.13, 5.30]
            }
          ]
        })
      end)

      assert {:ok, result} =
               ChartData.focus(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 screener: "america",
                 interval: "1d",
                 include_pivots: false
               })

      assert result.symbol == "NASDAQ:TSLA"
      assert result.close == 253.80
      assert not Map.has_key?(result, :pivot_points)
    end

    test "fetches crypto chart data" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "BINANCE:BTCUSD",
              "d" => [
                42_150.0, 41_800.0, 42_500.0, 41_500.0,
                1_250_000_000, 0.84, 350.0,
                40_000.0, 40_800.0, 41_500.0, 42_200.0,
                42_900.0, 43_600.0, 44_300.0
              ]
            }
          ]
        })
      end)

      assert {:ok, result} =
               ChartData.focus(%{
                 symbol: "BTCUSD",
                 exchange: "BINANCE",
                 screener: "crypto",
                 interval: "1h"
               })

      assert result.symbol == "BINANCE:BTCUSD"
      assert result.close == 42_150.0
      assert result.volume == 1_250_000_000
    end

    test "returns error when no data available" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"data" => []})
      end)

      assert {:error, "No data returned for NASDAQ:TSLA"} =
               ChartData.focus(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ"
               })
    end
  end

  describe "schema validation" do
    test "validates lens schema" do
      lens = ChartData.view()

      assert lens.name == "TradingView Chart Data"
      assert Map.has_key?(lens.schema.properties, :symbol)
      assert Map.has_key?(lens.schema.properties, :exchange)
      assert Map.has_key?(lens.schema.properties, :include_pivots)
      assert lens.schema.required == ["symbol", "exchange"]
    end
  end
end
