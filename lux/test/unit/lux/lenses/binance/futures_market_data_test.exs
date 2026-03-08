defmodule Lux.Lenses.Binance.FuturesMarketDataTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Binance.FuturesMarketData

  setup do
    Req.Test.stub(Lux.Binance.FuturesMock, fn conn ->
      path = conn.request_path

      result = cond do
        String.contains?(path, "fundingRate") ->
          [%{"symbol" => "BTCUSDT", "fundingRate" => "0.00010000", "fundingTime" => 1700000000000, "markPrice" => "65000.50"}]

        String.contains?(path, "premiumIndex") ->
          %{"symbol" => "BTCUSDT", "markPrice" => "65000.50", "indexPrice" => "64999.00",
            "lastFundingRate" => "0.00010000", "nextFundingTime" => 1700003600000, "interestRate" => "0.00010000"}

        String.contains?(path, "openInterest") ->
          %{"symbol" => "BTCUSDT", "openInterest" => "12345.678", "time" => 1700000000000}

        String.contains?(path, "allForceOrders") ->
          [%{"symbol" => "BTCUSDT", "side" => "SELL", "orderType" => "LIMIT", "origQty" => "0.5",
             "price" => "64000", "averagePrice" => "63950", "status" => "FILLED", "time" => 1700000000}]

        String.contains?(path, "klines") ->
          [[1700000000000, "65000", "65500", "64500", "65200", "1000", 1700003599999]]

        true -> %{}
      end

      Req.Test.json(conn, result)
    end)
    :ok
  end

  test "funding_rate" do
    assert {:ok, result} = FuturesMarketData.focus(%{action: "funding_rate", symbol: "BTCUSDT", plug: {Req.Test, Lux.Binance.FuturesMock}})
    assert length(result.funding_rates) == 1
    assert hd(result.funding_rates).funding_rate == 0.0001
  end

  test "mark_price" do
    assert {:ok, result} = FuturesMarketData.focus(%{action: "mark_price", symbol: "BTCUSDT", plug: {Req.Test, Lux.Binance.FuturesMock}})
    assert hd(result.prices).mark_price == 65000.50
  end

  test "open_interest" do
    assert {:ok, result} = FuturesMarketData.focus(%{action: "open_interest", symbol: "BTCUSDT", plug: {Req.Test, Lux.Binance.FuturesMock}})
    assert result.open_interest == 12345.678
  end

  test "liquidations" do
    assert {:ok, result} = FuturesMarketData.focus(%{action: "liquidations", symbol: "BTCUSDT", plug: {Req.Test, Lux.Binance.FuturesMock}})
    assert result.count == 1
    assert hd(result.liquidations).side == "SELL"
  end

  test "klines" do
    assert {:ok, result} = FuturesMarketData.focus(%{action: "klines", symbol: "BTCUSDT", interval: "1h", plug: {Req.Test, Lux.Binance.FuturesMock}})
    assert result.count == 1
    assert hd(result.klines).close == 65200.0
  end
end
