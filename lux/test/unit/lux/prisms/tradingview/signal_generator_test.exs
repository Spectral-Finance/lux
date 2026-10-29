defmodule Lux.Prisms.TradingView.SignalGeneratorTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.TradingView.SignalGenerator

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  @bullish_data_values [
    # Recommendations: All, MA, Other
    0.45, 0.55, 0.32,
    # Oscillators: RSI, RSI[1], Stoch.K, Stoch.D, Stoch.K[1], Stoch.D[1]
    38.5, 35.0, 25.0, 22.0, 23.0, 20.0,
    # CCI20, CCI20[1], ADX, ADX+DI, ADX-DI, ADX+DI[1], ADX-DI[1]
    120.0, 80.0, 28.5, 32.0, 18.0, 30.0, 20.0,
    # AO, AO[1], AO[2], Mom, Mom[1]
    8.50, -1.0, -3.0, 5.20, 3.80,
    # MACD.macd, MACD.signal, W.R, BBPower, UO
    2.15, 1.80, -75.0, 3.40, 55.60,
    # Moving averages: EMA10-SMA200, Ichimoku, VWMA, HullMA9
    248.0, 246.0, 245.0, 243.0, 242.0, 240.0,
    238.0, 235.0, 230.0, 228.0, 220.0, 215.0,
    242.0, 244.0, 249.0,
    # close
    253.80
  ]

  @bearish_data_values [
    # Recommendations
    -0.45, -0.55, -0.32,
    # Oscillators: RSI high (overbought), Stoch high
    75.0, 78.0, 85.0, 82.0, 87.0, 84.0,
    # CCI20, CCI20[1], ADX, ADX+DI (low), ADX-DI (high)
    -120.0, -80.0, 28.5, 15.0, 35.0, 17.0, 33.0,
    # AO negative, Mom negative
    -8.50, 1.0, 3.0, -5.20, -3.80,
    # MACD below signal, W.R high, BBPower negative
    -2.15, -1.80, -15.0, -3.40, 25.0,
    # MAs all above close
    260.0, 262.0, 265.0, 267.0, 268.0, 270.0,
    272.0, 275.0, 280.0, 282.0, 290.0, 295.0,
    270.0, 272.0, 262.0,
    # close
    253.80
  ]

  describe "run/1" do
    test "generates bullish signal with bullish indicator data" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => @bullish_data_values
            }
          ]
        })
      end)

      assert {:ok, result} =
               SignalGenerator.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 screener: "america",
                 interval: "1d"
               })

      assert result.symbol == "NASDAQ:TSLA"
      assert result.signal in ["BUY", "STRONG_BUY"]
      assert result.confidence >= 0.0
      assert result.confidence <= 1.0
      assert result.strength in ["WEAK", "MODERATE", "STRONG"]
      assert is_binary(result.summary)
      assert Map.has_key?(result.indicators, :rsi)
      assert Map.has_key?(result.indicators, :macd)
      assert Map.has_key?(result.indicators, :stochastic)
      assert Map.has_key?(result.indicators, :adx)
      assert Map.has_key?(result.indicators, :moving_averages)
    end

    test "generates bearish signal with bearish indicator data" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => @bearish_data_values
            }
          ]
        })
      end)

      assert {:ok, result} =
               SignalGenerator.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 screener: "america",
                 interval: "1d"
               })

      assert result.signal in ["SELL", "STRONG_SELL"]
    end

    test "includes individual indicator analysis" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => @bullish_data_values
            }
          ]
        })
      end)

      assert {:ok, result} =
               SignalGenerator.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ"
               })

      # Check RSI analysis
      assert Map.has_key?(result.indicators.rsi, :signal)
      assert Map.has_key?(result.indicators.rsi, :value)
      assert result.indicators.rsi.value == 38.5

      # Check MACD analysis
      assert Map.has_key?(result.indicators.macd, :signal)
      assert Map.has_key?(result.indicators.macd, :macd)
      assert Map.has_key?(result.indicators.macd, :signal_line)
      assert Map.has_key?(result.indicators.macd, :crossover)

      # Check Stochastic
      assert Map.has_key?(result.indicators.stochastic, :k)
      assert Map.has_key?(result.indicators.stochastic, :d)

      # Check ADX
      assert Map.has_key?(result.indicators.adx, :trend_strength)
      assert result.indicators.adx.value == 28.5

      # Check MA summary
      assert Map.has_key?(result.indicators.moving_averages, :buy_count)
      assert Map.has_key?(result.indicators.moving_averages, :sell_count)
    end

    test "returns error when no data available" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"data" => []})
      end)

      assert {:error, "No data returned for NASDAQ:TSLA"} =
               SignalGenerator.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ"
               })
    end

    test "handles API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "Server error"}))
      end)

      assert {:error, _} =
               SignalGenerator.run(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ"
               })
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = SignalGenerator.view()

      assert prism.name == "TradingView Signal Generator"
      assert prism.input_schema.required == ["symbol", "exchange"]
      assert Map.has_key?(prism.input_schema.properties, :symbol)
      assert Map.has_key?(prism.input_schema.properties, :exchange)
      assert Map.has_key?(prism.input_schema.properties, :interval)
    end

    test "validates output schema" do
      prism = SignalGenerator.view()

      assert "symbol" in prism.output_schema.required
      assert "signal" in prism.output_schema.required
      assert "confidence" in prism.output_schema.required
      assert Map.has_key?(prism.output_schema.properties, :indicators)
    end
  end
end
