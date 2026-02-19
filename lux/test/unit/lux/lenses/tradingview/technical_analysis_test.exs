defmodule Lux.Lenses.TradingView.TechnicalAnalysisTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.TradingView.TechnicalAnalysis

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "fetches and parses technical analysis for a symbol" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"

        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [0.32, 0.45, 0.12]
            }
          ]
        })
      end)

      assert {:ok, result} =
               TechnicalAnalysis.focus(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 screener: "america",
                 interval: "1d"
               })

      assert result.symbol == "NASDAQ:TSLA"
      assert result.recommendation == "BUY"
      assert result.summary.recommendation == 0.32
      assert result.moving_averages.recommendation == 0.45
      assert result.moving_averages.computed_signal == "BUY"
      assert result.oscillators.recommendation == 0.12
      assert result.oscillators.computed_signal == "BUY"
    end

    test "handles strong buy recommendation" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "BINANCE:BTCUSD",
              "d" => [0.65, 0.72, 0.55]
            }
          ]
        })
      end)

      assert {:ok, result} =
               TechnicalAnalysis.focus(%{
                 symbol: "BTCUSD",
                 exchange: "BINANCE",
                 screener: "crypto",
                 interval: "4h"
               })

      assert result.recommendation == "STRONG_BUY"
    end

    test "handles sell recommendation" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [-0.35, -0.42, -0.20]
            }
          ]
        })
      end)

      assert {:ok, result} =
               TechnicalAnalysis.focus(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 screener: "america"
               })

      assert result.recommendation == "SELL"
    end

    test "handles neutral recommendation" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [0.02, -0.05, 0.08]
            }
          ]
        })
      end)

      assert {:ok, result} =
               TechnicalAnalysis.focus(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ"
               })

      assert result.recommendation == "NEUTRAL"
    end

    test "returns error when no data is returned" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"data" => []})
      end)

      assert {:error, "No data returned for NASDAQ:TSLA"} =
               TechnicalAnalysis.focus(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ"
               })
    end

    test "uses default screener and interval" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [0.32, 0.45, 0.12]
            }
          ]
        })
      end)

      assert {:ok, _result} =
               TechnicalAnalysis.focus(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ"
               })
    end
  end

  describe "schema validation" do
    test "validates lens schema" do
      lens = TechnicalAnalysis.view()

      assert lens.name == "TradingView Technical Analysis"
      assert Map.has_key?(lens.schema.properties, :symbol)
      assert Map.has_key?(lens.schema.properties, :exchange)
      assert Map.has_key?(lens.schema.properties, :screener)
      assert Map.has_key?(lens.schema.properties, :interval)
      assert lens.schema.required == ["symbol", "exchange"]
    end

    test "schema has correct interval enum" do
      lens = TechnicalAnalysis.view()
      interval_prop = lens.schema.properties.interval

      assert "1m" in interval_prop.enum
      assert "1d" in interval_prop.enum
      assert "1W" in interval_prop.enum
    end
  end
end
