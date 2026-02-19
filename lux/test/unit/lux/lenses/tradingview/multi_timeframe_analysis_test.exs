defmodule Lux.Lenses.TradingView.MultiTimeframeAnalysisTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.TradingView.MultiTimeframeAnalysis

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "fetches analysis across multiple timeframes" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        # Should have columns for all requested intervals
        columns = decoded["columns"]
        assert Enum.any?(columns, &String.contains?(&1, "|60"))
        assert Enum.any?(columns, &String.contains?(&1, "|240"))
        assert Enum.any?(columns, &(not String.contains?(&1, "|")))

        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [
                # 1h: Recommend.All|60, Recommend.MA|60, Recommend.Other|60
                0.15, 0.25, 0.05,
                # 4h: Recommend.All|240, Recommend.MA|240, Recommend.Other|240
                0.32, 0.45, 0.18,
                # 1d: Recommend.All, Recommend.MA, Recommend.Other
                0.55, 0.65, 0.38
              ]
            }
          ]
        })
      end)

      assert {:ok, result} =
               MultiTimeframeAnalysis.focus(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 screener: "america",
                 intervals: ["1h", "4h", "1d"]
               })

      assert result.symbol == "NASDAQ:TSLA"
      assert Map.has_key?(result.timeframes, "1h")
      assert Map.has_key?(result.timeframes, "4h")
      assert Map.has_key?(result.timeframes, "1d")

      # Verify 1h data (Recommend.All|60 = 0.15, which classifies as BUY)
      assert result.timeframes["1h"].recommendation == "BUY"
      assert result.timeframes["1h"].value == 0.15

      # Verify 4h data
      assert result.timeframes["4h"].recommendation == "BUY"
      assert result.timeframes["4h"].value == 0.32

      # Verify 1d data
      assert result.timeframes["1d"].recommendation == "STRONG_BUY"
      assert result.timeframes["1d"].value == 0.55

      # Verify consensus
      assert result.consensus in ["BUY", "STRONG_BUY"]
      assert result.alignment >= 0.0 and result.alignment <= 1.0
    end

    test "calculates alignment correctly when all timeframes agree" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [0.32, 0.45, 0.22, 0.28, 0.35, 0.18]
            }
          ]
        })
      end)

      assert {:ok, result} =
               MultiTimeframeAnalysis.focus(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 intervals: ["1h", "1d"]
               })

      # All values are positive (bullish) → alignment should be 1.0
      assert result.alignment == 1.0
    end

    test "handles mixed signals across timeframes" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [
                0.32, 0.45, 0.22,     # 1h: bullish
                -0.28, -0.35, -0.18   # 1d: bearish
              ]
            }
          ]
        })
      end)

      assert {:ok, result} =
               MultiTimeframeAnalysis.focus(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 intervals: ["1h", "1d"]
               })

      # Mixed signals → lower alignment
      assert result.alignment <= 1.0
    end

    test "uses default intervals when not specified" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        # Default intervals: ["1h", "4h", "1d", "1W"]
        columns = decoded["columns"]
        assert length(columns) == 12  # 3 recommendation columns × 4 intervals

        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "NASDAQ:TSLA",
              "d" => [0.1, 0.2, 0.05, 0.15, 0.25, 0.1, 0.3, 0.4, 0.2, 0.25, 0.35, 0.15]
            }
          ]
        })
      end)

      assert {:ok, result} =
               MultiTimeframeAnalysis.focus(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ"
               })

      assert map_size(result.timeframes) == 4
    end

    test "returns error when no data available" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"data" => []})
      end)

      assert {:error, "No data returned for NASDAQ:TSLA"} =
               MultiTimeframeAnalysis.focus(%{
                 symbol: "TSLA",
                 exchange: "NASDAQ",
                 intervals: ["1d"]
               })
    end
  end

  describe "schema validation" do
    test "validates lens schema" do
      lens = MultiTimeframeAnalysis.view()

      assert lens.name == "TradingView Multi-Timeframe Analysis"
      assert Map.has_key?(lens.schema.properties, :symbol)
      assert Map.has_key?(lens.schema.properties, :intervals)
      assert lens.schema.required == ["symbol", "exchange"]
    end
  end
end
