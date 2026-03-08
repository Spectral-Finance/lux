defmodule Lux.Prisms.TradingView.TechnicalAnalysisTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.TradingView.TechnicalRating
  alias Lux.Prisms.TradingView.TechnicalAnalysis

  setup do
    Req.Test.verify_on_exit!()
  end

  @oscillator_count 18
  @ma_count 15

  defp mock_rating_response(rec_all, rec_osc, rec_ma) do
    %{
      "data" => [
        %{
          "s" => "BINANCE:BTCUSDT",
          "d" =>
            [rec_all, rec_osc, rec_ma] ++
              List.duplicate(50.0, @oscillator_count) ++
              List.duplicate(68000.0, @ma_count)
        }
      ]
    }
  end

  describe "handler/2" do
    test "performs multi-timeframe analysis with bullish alignment" do
      # Stub all timeframes to return bullish
      Req.Test.stub(TechnicalRating, fn conn ->
        Req.Test.json(conn, mock_rating_response(0.45, 0.3, 0.6))
      end)

      assert {:ok, result} =
               TechnicalAnalysis.handler(
                 %{"symbol" => "BINANCE:BTCUSDT", "timeframes" => ["60", "240", "D"]},
                 nil
               )

      assert result.symbol == "BINANCE:BTCUSDT"
      assert result.signal in [:buy, :strong_buy]
      assert result.confidence > 0
      assert result.alignment in [:full_bullish, :mostly_bullish]
      assert is_binary(result.summary)
      assert result.timestamp != nil
    end

    test "performs analysis with bearish alignment" do
      Req.Test.stub(TechnicalRating, fn conn ->
        Req.Test.json(conn, mock_rating_response(-0.55, -0.4, -0.7))
      end)

      assert {:ok, result} =
               TechnicalAnalysis.handler(
                 %{"symbol" => "BINANCE:BTCUSDT", "timeframes" => ["60", "D"]},
                 nil
               )

      assert result.signal in [:sell, :strong_sell]
      assert result.alignment in [:full_bearish, :mostly_bearish]
    end

    test "handles neutral/mixed signals" do
      Req.Test.stub(TechnicalRating, fn conn ->
        Req.Test.json(conn, mock_rating_response(0.02, -0.01, 0.05))
      end)

      assert {:ok, result} =
               TechnicalAnalysis.handler(
                 %{"symbol" => "BINANCE:BTCUSDT", "timeframes" => ["60", "D"]},
                 nil
               )

      assert result.signal == :neutral
    end

    test "applies trend_following strategy" do
      Req.Test.stub(TechnicalRating, fn conn ->
        Req.Test.json(conn, mock_rating_response(0.3, 0.2, 0.4))
      end)

      assert {:ok, result} =
               TechnicalAnalysis.handler(
                 %{
                   "symbol" => "BINANCE:BTCUSDT",
                   "timeframes" => ["60", "D"],
                   "strategy" => "trend_following"
                 },
                 nil
               )

      assert result.strategy == "trend_following"
      assert result.signal in [:buy, :strong_buy]
    end

    test "applies mean_reversion strategy" do
      Req.Test.stub(TechnicalRating, fn conn ->
        Req.Test.json(conn, mock_rating_response(0.8, 0.7, 0.9))
      end)

      assert {:ok, result} =
               TechnicalAnalysis.handler(
                 %{
                   "symbol" => "BINANCE:BTCUSDT",
                   "timeframes" => ["D"],
                   "strategy" => "mean_reversion"
                 },
                 nil
               )

      assert result.strategy == "mean_reversion"
      # Mean reversion should reverse extreme bullish to sell
      assert result.signal in [:sell, :strong_sell, :neutral]
    end

    test "uses default timeframes when not specified" do
      Req.Test.stub(TechnicalRating, fn conn ->
        Req.Test.json(conn, mock_rating_response(0.2, 0.1, 0.3))
      end)

      assert {:ok, result} =
               TechnicalAnalysis.handler(%{"symbol" => "BINANCE:BTCUSDT"}, nil)

      # Should have analyzed 3 default timeframes (60, 240, D)
      assert map_size(result.timeframe_analysis) == 3
    end
  end
end
