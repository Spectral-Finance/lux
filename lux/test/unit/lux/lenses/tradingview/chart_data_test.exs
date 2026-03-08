defmodule Lux.Lenses.TradingView.ChartDataTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.TradingView.ChartData

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "focus/1" do
    test "fetches OHLCV data for a crypto symbol" do
      Req.Test.stub(ChartData, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["symbols"]["tickers"] == ["BINANCE:BTCUSDT"]
        assert is_list(decoded["columns"])

        Req.Test.json(conn, %{
          "data" => [
            %{
              "s" => "BINANCE:BTCUSDT",
              "d" => [68000.0, 68500.0, 67500.0, 68200.0, 12345.6, 1.5, 1020.0,
                      "BTCUSDT", "BINANCE", "Bitcoin / TetherUS", "crypto", "USD"]
            }
          ]
        })
      end)

      assert {:ok, %{data: [result], count: 1}} =
               ChartData.focus(%{symbol: "BINANCE:BTCUSDT", interval: "60"})

      assert result.symbol == "BINANCE:BTCUSDT"
      assert result.open == 68000.0
      assert result.high == 68500.0
      assert result.low == 67500.0
      assert result.close == 68200.0
      assert result.volume == 12345.6
    end

    test "handles error response" do
      Req.Test.stub(ChartData, fn conn ->
        Req.Test.json(conn, %{"error" => "Invalid symbol"})
      end)

      assert {:error, "Invalid symbol"} =
               ChartData.focus(%{symbol: "INVALID:XXX"})
    end

    test "handles empty data" do
      Req.Test.stub(ChartData, fn conn ->
        Req.Test.json(conn, %{"data" => []})
      end)

      assert {:ok, %{data: [], count: 0}} =
               ChartData.focus(%{symbol: "BINANCE:BTCUSDT"})
    end

    test "parses symbol without exchange prefix" do
      Req.Test.stub(ChartData, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        # Should default to BINANCE
        assert decoded["symbols"]["tickers"] == ["BINANCE:BTCUSDT"]

        Req.Test.json(conn, %{"data" => []})
      end)

      ChartData.focus(%{symbol: "BTCUSDT"})
    end
  end
end
