defmodule Lux.Lenses.Hyperliquid.ClearinghouseStateLensTest do
  use UnitCase, async: true

  alias Lux.Lenses.Hyperliquid.ClearinghouseStateLens

  @sample_address "0x0403369c02199a0cb827f4d6492927e9fa5668d5"

  @sample_clearinghouse %{
    "crossMarginSummary" => %{
      "accountValue" => "10000.0",
      "totalMarginUsed" => "1000.0",
      "totalNtlPos" => "5000.0",
      "totalRawUsd" => "10000.0"
    },
    "crossMaintenanceMarginRatio" => "0.05",
    "withdrawable" => "9000.0",
    "assetPositions" => [
      %{
        "type" => "oneWay",
        "position" => %{
          "coin" => "ETH",
          "szi" => "2.0",
          "entryPx" => "2500.0",
          "liquidationPx" => "2000.0",
          "marginUsed" => "500.0",
          "positionValue" => "5000.0",
          "unrealizedPnl" => "200.0",
          "returnOnEquity" => "0.4",
          "leverage" => %{"type" => "cross", "value" => 10}
        }
      }
    ]
  }

  describe "schema and configuration" do
    test "view/0 returns valid lens struct" do
      lens = ClearinghouseStateLens.view()
      assert lens.name == "Hyperliquid Clearinghouse State Lens"
      assert lens.method == :post
      assert lens.url == "https://api.hyperliquid.xyz/info"
      assert lens.schema.required == ["user"]
    end
  end

  describe "before_focus/1" do
    test "formats clearinghouseState request payload" do
      payload = ClearinghouseStateLens.before_focus(%{user: @sample_address})
      assert payload["type"] == "clearinghouseState"
      assert payload["user"] == @sample_address
    end
  end

  describe "after_focus/1" do
    test "transforms clearinghouse response correctly" do
      assert {:ok, result} = ClearinghouseStateLens.after_focus(@sample_clearinghouse)

      assert result.account_value == 10000.0
      assert result.total_margin_used == 1000.0
      assert result.total_ntl_pos == 5000.0
      assert result.withdrawable == 9000.0
      assert result.maintenance_margin_ratio == 0.05

      assert length(result.positions) == 1
      [pos] = result.positions
      assert pos.coin == "ETH"
      assert pos.size == 2.0
      assert pos.entry_price == 2500.0
      assert pos.liquidation_price == 2000.0
      assert pos.unrealized_pnl == 200.0
      assert pos.return_on_equity == 0.4
    end

    test "handles API errors gracefully" do
      assert {:error, "User not found"} =
               ClearinghouseStateLens.after_focus(%{"error" => "User not found"})
    end
  end
end
