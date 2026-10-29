defmodule Lux.Lenses.TradingView.IndicatorValuesTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.TradingView.IndicatorValues

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "fetches all oscillators and moving averages" do
      # Build expected response with all oscillator + MA columns
      oscillator_values = [
        58.32, 55.0,     # RSI, RSI[1]
        72.15, 68.40,    # Stoch.K, Stoch.D
        70.0, 66.0,      # Stoch.K[1], Stoch.D[1]
        102.50, 90.0,    # CCI20, CCI20[1]
        25.80, 30.5,     # ADX, ADX+DI
        18.2, 28.0,      # ADX-DI, ADX+DI[1]
        16.5,            # ADX-DI[1]
        8.50, 7.20, 6.0, # AO, AO[1], AO[2]
        5.20, 4.80,      # Mom, Mom[1]
        2.15, 1.80,      # MACD.macd, MACD.signal
        -27.85,          # W.R
        3.40,            # BBPower
        55.60            # UO
      ]

      ma_values = [
        250.30, 249.80,  # EMA10, SMA10
        248.50, 247.90,  # EMA20, SMA20
        245.60, 244.30,  # EMA30, SMA30
        240.20, 238.50,  # EMA50, SMA50
        230.10, 228.40,  # EMA100, SMA100
        215.80, 213.20,  # EMA200, SMA200
        242.50,          # Ichimoku.BLine
        246.80,          # VWMA
        251.10           # HullMA9
      ]

      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => oscillator_values ++ ma_values
            }
          ]
        })
      end)

      assert {:ok, result} =
               IndicatorValues.focus(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 screener: "america",
                 interval: "1d"
               })

      assert result.symbol == "NASDAQ:TSLA"

      # Verify oscillators
      assert result.oscillators.rsi == 58.32
      assert result.oscillators.stoch_k == 72.15
      assert result.oscillators.stoch_d == 68.40
      assert result.oscillators.cci == 102.50
      assert result.oscillators.adx == 25.80
      assert result.oscillators.macd == 2.15
      assert result.oscillators.macd_signal == 1.80
      assert result.oscillators.momentum == 5.20
      assert result.oscillators.williams_r == -27.85
      assert result.oscillators.bbpower == 3.40
      assert result.oscillators.ultimate_osc == 55.60
      assert result.oscillators.awesome_osc == 8.50

      # Verify moving averages
      assert result.moving_averages.ema10 == 250.30
      assert result.moving_averages.sma10 == 249.80
      assert result.moving_averages.ema50 == 240.20
      assert result.moving_averages.sma200 == 213.20
      assert result.moving_averages.ichimoku_baseline == 242.50
      assert result.moving_averages.vwma == 246.80
      assert result.moving_averages.hull_ma9 == 251.10
    end

    test "fetches specific indicators when requested" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "BINANCE:BTCUSD",
              "d" => [58.32, 2.15, 1.80]
            }
          ]
        })
      end)

      assert {:ok, result} =
               IndicatorValues.focus(%{
                 symbol: "BTCUSD",
                 exchange: "BINANCE",
                 screener: "crypto",
                 interval: "4h",
                 indicators: ["RSI", "MACD.macd", "MACD.signal"]
               })

      assert result.symbol == "BINANCE:BTCUSD"
      assert Map.has_key?(result, :indicators)
      assert result.indicators["RSI"] == 58.32
      assert result.indicators["MACD.macd"] == 2.15
      assert result.indicators["MACD.signal"] == 1.80
    end

    test "returns error when no data available" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"data" => []})
      end)

      assert {:error, "No data returned for NASDAQ:TSLA"} =
               IndicatorValues.focus(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ"
               })
    end
  end

  describe "schema validation" do
    test "validates lens schema" do
      lens = IndicatorValues.view()

      assert lens.name == "TradingView Indicator Values"
      assert Map.has_key?(lens.schema.properties, :symbol)
      assert Map.has_key?(lens.schema.properties, :exchange)
      assert Map.has_key?(lens.schema.properties, :indicators)
      assert lens.schema.required == ["symbol", "exchange"]
    end
  end
end
