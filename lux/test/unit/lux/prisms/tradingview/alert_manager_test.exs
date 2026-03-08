defmodule Lux.Prisms.TradingView.AlertManagerTest do
  use UnitCase, async: true

  alias Lux.Prisms.TradingView.AlertManager

  describe "handler/2 - create" do
    test "creates a price alert" do
      assert {:ok, alert} =
               AlertManager.handler(
                 %{
                   "action" => "create",
                   "symbol" => "BINANCE:BTCUSDT",
                   "type" => "price_above",
                   "value" => 100_000.0,
                   "message" => "BTC 100K!"
                 },
                 nil
               )

      assert alert.alert_id =~ "alert_"
      assert alert.symbol == "BINANCE:BTCUSDT"
      assert alert.type == :price_above
      assert alert.value == 100_000.0
      assert alert.status == :active
    end
  end

  describe "handler/2 - list" do
    test "lists all alerts" do
      alerts = [
        %{alert_id: "a1", symbol: "BINANCE:BTCUSDT"},
        %{alert_id: "a2", symbol: "BINANCE:ETHUSDT"}
      ]

      assert {:ok, result} =
               AlertManager.handler(%{"action" => "list", "alerts" => alerts}, nil)

      assert result.count == 2
    end

    test "filters by symbol" do
      alerts = [
        %{alert_id: "a1", symbol: "BINANCE:BTCUSDT"},
        %{alert_id: "a2", symbol: "BINANCE:ETHUSDT"}
      ]

      assert {:ok, result} =
               AlertManager.handler(
                 %{"action" => "list", "alerts" => alerts, "symbol" => "BINANCE:BTCUSDT"},
                 nil
               )

      assert result.count == 1
    end
  end

  describe "handler/2 - delete" do
    test "deletes an alert by ID" do
      alerts = [
        %{alert_id: "a1", symbol: "BTC"},
        %{alert_id: "a2", symbol: "ETH"}
      ]

      assert {:ok, result} =
               AlertManager.handler(
                 %{"action" => "delete", "alert_id" => "a1", "alerts" => alerts},
                 nil
               )

      assert result.deleted == "a1"
      assert result.remaining == 1
    end
  end

  describe "handler/2 - unknown action" do
    test "returns error for unknown action" do
      assert {:error, _} = AlertManager.handler(%{"action" => "explode"}, nil)
    end
  end
end
