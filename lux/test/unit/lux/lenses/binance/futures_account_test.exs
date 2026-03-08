defmodule Lux.Lenses.Binance.FuturesAccountTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Binance.FuturesAccount

  setup do
    Req.Test.stub(Lux.Binance.FuturesAccMock, fn conn ->
      path = conn.request_path

      result = cond do
        String.contains?(path, "positionRisk") ->
          [
            %{"symbol" => "BTCUSDT", "positionAmt" => "0.5", "entryPrice" => "64000",
              "markPrice" => "65000", "unRealizedProfit" => "500", "leverage" => "10",
              "marginType" => "cross", "liquidationPrice" => "58000"},
            %{"symbol" => "ETHUSDT", "positionAmt" => "0", "entryPrice" => "0",
              "markPrice" => "3500", "unRealizedProfit" => "0", "leverage" => "1",
              "marginType" => "cross", "liquidationPrice" => "0"}
          ]

        String.contains?(path, "balance") ->
          [
            %{"asset" => "USDT", "balance" => "10000.50", "availableBalance" => "8500.25", "crossUnPnl" => "500"},
            %{"asset" => "BNB", "balance" => "0", "availableBalance" => "0", "crossUnPnl" => "0"}
          ]

        String.contains?(path, "income") ->
          [
            %{"symbol" => "BTCUSDT", "incomeType" => "REALIZED_PNL", "income" => "150.50", "asset" => "USDT", "time" => 1700000000000},
            %{"symbol" => "BTCUSDT", "incomeType" => "FUNDING_FEE", "income" => "-2.30", "asset" => "USDT", "time" => 1700003600000}
          ]

        true -> %{}
      end

      Req.Test.json(conn, result)
    end)
    :ok
  end

  test "positions filters zero amounts" do
    assert {:ok, result} = FuturesAccount.focus(%{action: "positions", api_key: "k", api_secret: "s", plug: {Req.Test, Lux.Binance.FuturesAccMock}})
    assert result.count == 1
    pos = hd(result.positions)
    assert pos.symbol == "BTCUSDT"
    assert pos.side == "LONG"
    assert pos.unrealized_pnl == 500.0
    assert pos.leverage == 10
  end

  test "balance filters zero balances" do
    assert {:ok, result} = FuturesAccount.focus(%{action: "balance", api_key: "k", api_secret: "s", plug: {Req.Test, Lux.Binance.FuturesAccMock}})
    assert result.count == 1
    assert hd(result.balances).asset == "USDT"
    assert hd(result.balances).available == 8500.25
  end

  test "income history" do
    assert {:ok, result} = FuturesAccount.focus(%{action: "income", api_key: "k", api_secret: "s", plug: {Req.Test, Lux.Binance.FuturesAccMock}})
    assert result.count == 2
    pnl = Enum.find(result.income, &(&1.income_type == "REALIZED_PNL"))
    assert pnl.income == 150.50
  end
end
