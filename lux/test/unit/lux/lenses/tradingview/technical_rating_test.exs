defmodule Lux.Lenses.TradingView.TechnicalRatingTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.TradingView.TechnicalRating

  setup do
    Req.Test.verify_on_exit!()
  end

  @oscillator_count 18
  @ma_count 15

  defp mock_values(rec_all, rec_osc, rec_ma) do
    # 3 summary + 18 oscillator + 15 MA values
    [rec_all, rec_osc, rec_ma] ++
      List.duplicate(50.0, @oscillator_count) ++
      List.duplicate(68000.0, @ma_count)
  end

  describe "focus/1" do
    test "fetches and parses technical ratings" do
      Req.Test.stub(TechnicalRating, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["symbols"]["tickers"] == ["BINANCE:BTCUSDT"]
        assert length(decoded["columns"]) == 3 + @oscillator_count + @ma_count

        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "BINANCE:BTCUSDT",
              "d" => mock_values(0.35, 0.12, 0.65)
            }
          ]
        })
      end)

      assert {:ok, result} = TechnicalRating.focus(%{symbol: "BINANCE:BTCUSDT", interval: "D"})

      assert result.symbol == "BINANCE:BTCUSDT"
      assert result.recommendation == "BUY"
      assert result.recommendation_value == 0.35
      assert result.oscillators.recommendation == "BUY"
      assert result.moving_averages.recommendation == "STRONG_BUY"
      assert result.summary.overall == "BUY"
      assert result.summary.signal_strength == :moderate
    end

    test "correctly classifies STRONG_SELL" do
      Req.Test.stub(TechnicalRating, fn conn ->
        Req.Test.json(conn, %{
          "data" => [%{"s" => "BINANCE:BTCUSDT", "d" => mock_values(-0.7, -0.6, -0.8)}]
        })
      end)

      assert {:ok, result} = TechnicalRating.focus(%{symbol: "BINANCE:BTCUSDT"})
      assert result.recommendation == "STRONG_SELL"
      assert result.summary.signal_strength == :strong
    end

    test "correctly classifies NEUTRAL" do
      Req.Test.stub(TechnicalRating, fn conn ->
        Req.Test.json(conn, %{
          "data" => [%{"s" => "BINANCE:BTCUSDT", "d" => mock_values(0.05, 0.02, 0.08)}]
        })
      end)

      assert {:ok, result} = TechnicalRating.focus(%{symbol: "BINANCE:BTCUSDT"})
      assert result.recommendation == "NEUTRAL"
    end

    test "handles empty data" do
      Req.Test.stub(TechnicalRating, fn conn ->
        Req.Test.json(conn, %{"data" => []})
      end)

      assert {:error, "No data found for symbol"} =
               TechnicalRating.focus(%{symbol: "BINANCE:UNKNOWN"})
    end

    test "handles error response" do
      Req.Test.stub(TechnicalRating, fn conn ->
        Req.Test.json(conn, %{"error" => "Rate limited"})
      end)

      assert {:error, "Rate limited"} = TechnicalRating.focus(%{symbol: "BINANCE:BTCUSDT"})
    end

    test "applies interval suffix to columns" do
      Req.Test.stub(TechnicalRating, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        # All columns should have |60 suffix for hourly
        assert Enum.all?(decoded["columns"], &String.ends_with?(&1, "|60"))

        Req.Test.json(conn, %{
          "data" => [%{"s" => "BINANCE:BTCUSDT", "d" => mock_values(0.2, 0.1, 0.3)}]
        })
      end)

      TechnicalRating.focus(%{symbol: "BINANCE:BTCUSDT", interval: "60"})
    end
  end
end
