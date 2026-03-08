defmodule Lux.Lenses.Binance.MarketHistoryTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Binance.MarketHistory

  setup do
    Req.Test.stub(Lux.Integrations.Binance.ClientMock, fn conn ->
      case conn.request_path do
        "/api/v3/klines" ->
          Req.Test.json(conn, [
            [1_704_067_200_000, "42000.00", "42500.00", "41800.00", "42300.00",
             "1234.567", 1_704_153_599_999, "52345678.90", 50_000, "600.123",
             "25345678.90", "0"],
            [1_704_153_600_000, "42300.00", "43000.00", "42100.00", "42800.00",
             "1567.890", 1_704_239_999_999, "67345678.90", 60_000, "700.456",
             "30345678.90", "0"]
          ])

        "/fapi/v1/klines" ->
          Req.Test.json(conn, [
            [1_704_067_200_000, "42000.00", "42500.00", "41800.00", "42300.00",
             "1234.567", 1_704_153_599_999, "52345678.90", 50_000, "600.123",
             "25345678.90", "0"]
          ])
      end
    end)

    :ok
  end

  describe "focus/2" do
    test "fetches spot klines" do
      assert {:ok, klines} =
               MarketHistory.focus(%{
                 symbol: "BTCUSDT",
                 interval: "1h",
                 limit: 2,
                 plug: {Req.Test, Lux.Integrations.Binance.ClientMock}
               })

      assert length(klines) == 2

      [first | _] = klines
      assert first.open == "42000.00"
      assert first.high == "42500.00"
      assert first.low == "41800.00"
      assert first.close == "42300.00"
      assert first.volume == "1234.567"
    end

    test "fetches futures klines" do
      assert {:ok, klines} =
               MarketHistory.focus(%{
                 symbol: "BTCUSDT",
                 interval: "1h",
                 futures: true,
                 plug: {Req.Test, Lux.Integrations.Binance.ClientMock}
               })

      assert length(klines) == 1
    end
  end

  describe "valid_intervals/0" do
    test "includes standard intervals" do
      intervals = MarketHistory.valid_intervals()
      assert "1m" in intervals
      assert "5m" in intervals
      assert "1h" in intervals
      assert "1d" in intervals
      assert "1w" in intervals
    end
  end
end
