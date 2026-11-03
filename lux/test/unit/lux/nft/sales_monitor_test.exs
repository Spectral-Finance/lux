defmodule Lux.Nft.SalesMonitorTest do
  use UnitCase, async: true

  alias Lux.Nft.SalesMonitor

  describe "filter_wash_trades/1" do
    test "detects identical buyer/seller wash trades" do
      sales = [
        %{"buyer" => "0xAlice", "seller" => "0xBob", "price_eth" => "10.0"},
        %{"buyer" => "0xWashTrader", "seller" => "0xWashTrader", "price_eth" => "50.0"},
        %{"buyer" => "0xCharlie", "seller" => "0xDavid", "price_eth" => "12.0"}
      ]

      result = SalesMonitor.filter_wash_trades(sales)

      assert length(result.clean_sales) == 2
      assert length(result.flagged_sales) == 1
      assert result.clean_volume_eth == 22.0
      assert result.wash_trading_pct > 60.0
    end
  end
end
