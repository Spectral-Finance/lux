defmodule Lux.Integrations.Hyperliquid.ModelsTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Hyperliquid.Models

  describe "parse_position/1" do
    test "parses a valid position from API response" do
      raw = %{
        "coin" => "ETH",
        "position" => %{
          "szi" => "1.0",
          "entryPx" => "2800.0",
          "leverage" => %{"value" => "2"},
          "liquidationPx" => "1400.0",
          "marginUsed" => "1400.0",
          "positionValue" => "2800.0",
          "returnOnEquity" => "0.15",
          "unrealizedPnl" => "420.0",
          "marginMode" => "cross",
          "maxLeverage" => "10"
        }
      }

      pos = Models.parse_position(raw)

      assert pos.asset == "ETH"
      assert pos.size == "1.0"
      assert pos.entry_price == "2800.0"
      assert pos.leverage == "2"
      assert pos.liquidation_price == "1400.0"
      assert pos.margin_used == "1400.0"
      assert pos.position_value == "2800.0"
      assert pos.return_on_equity == "0.15"
      assert pos.unrealized_pnl == "420.0"
      assert pos.margin_mode == "cross"
      assert pos.max_leverage == "10"
    end

    test "handles position without leverage info" do
      raw = %{
        "coin" => "BTC",
        "position" => %{
          "szi" => "0.5",
          "entryPx" => "60000.0",
          "liquidationPx" => "30000.0",
          "marginUsed" => "15000.0",
          "positionValue" => "30000.0",
          "returnOnEquity" => "0.05",
          "unrealizedPnl" => "1500.0",
          "marginMode" => "isolated",
          "maxLeverage" => "5"
        }
      }

      pos = Models.parse_position(raw)

      assert pos.asset == "BTC"
      assert pos.size == "0.5"
      assert pos.leverage == nil
    end
  end

  describe "parse_order/1" do
    test "parses a valid order from API response" do
      raw = %{
        "oid" => 123_456,
        "coin" => "ETH",
        "side" => "B",
        "origSz" => "0.1",
        "limitPx" => "2800.0",
        "orderType" => %{"limit" => %{"tif" => "Gtc"}},
        "reduceOnly" => false,
        "status" => "open",
        "totalSz" => "0.0",
        "avgPx" => nil,
        "timestamp" => 1_678_901_234,
        "hash" => nil,
        "error" => nil
      }

      order = Models.parse_order(raw)

      assert order.order_id == 123_456
      assert order.asset == "ETH"
      assert order.is_buy == true
      assert order.size == "0.1"
      assert order.price == "2800.0"
      assert order.order_type == %{"limit" => %{"tif" => "Gtc"}}
      assert order.status == "open"
    end

    test "parses a sell order correctly" do
      raw = %{
        "oid" => 789,
        "coin" => "BTC",
        "side" => "S",
        "sz" => "0.5",
        "limit_px" => "62000.0",
        "order_type" => %{"limit" => %{"tif" => "Ioc"}}
      }

      order = Models.parse_order(raw)

      assert order.order_id == 789
      assert order.asset == "BTC"
      assert order.is_buy == false
      assert order.price == "62000.0"
    end
  end

  describe "parse_account/1" do
    test "parses a valid account from API response" do
      raw = %{
        "address" => "0x1234567890abcdef",
        "crossMarginSummary" => %{
          "accountValue" => "10000.0",
          "totalMarginUsed" => "2000.0",
          "totalNtlPos" => "5000.0",
          "totalRawUsd" => "10000.0"
        },
        "crossMaintenanceMarginRatio" => "0.0625",
        "marginRatio" => "0.8",
        "withdrawable" => "8000.0",
        "assetPositions" => [
          %{
            "coin" => "ETH",
            "position" => %{
              "szi" => "1.0",
              "entryPx" => "2800.0",
              "leverage" => %{"value" => "2"},
              "liquidationPx" => "1400.0",
              "marginUsed" => "1400.0",
              "positionValue" => "2800.0",
              "returnOnEquity" => "0.15",
              "unrealizedPnl" => "420.0",
              "marginMode" => "cross",
              "maxLeverage" => "10"
            }
          }
        ]
      }

      account = Models.parse_account(raw)

      assert account.address == "0x1234567890abcdef"
      assert account.account_value == "10000.0"
      assert account.total_margin_used == "2000.0"
      assert account.maintenance_margin_ratio == "0.0625"
      assert length(account.positions) == 1
      assert hd(account.positions).asset == "ETH"
    end

    test "handles account with no positions" do
      raw = %{
        "address" => "0xempty",
        "crossMarginSummary" => %{
          "accountValue" => "5000.0",
          "totalMarginUsed" => "0.0",
          "totalNtlPos" => "0.0",
          "totalRawUsd" => "5000.0"
        }
      }

      account = Models.parse_account(raw)

      assert account.positions == []
      assert account.account_value == "5000.0"
    end
  end

  describe "parse_market_data/2" do
    test "parses market data correctly" do
      raw = %{
        "funding" => "0.0000125",
        "openInterest" => "1000000.0",
        "prevDayPx" => "2750.0",
        "dayNtlVlm" => "50000000.0",
        "premium" => "0.0001",
        "oraclePx" => "2800.5",
        "markPx" => "2800.0",
        "midPx" => "2800.0",
        "impactPxs" => ["2799.0", "2801.0"],
        "dayBaseVlm" => "18000.0",
        "szDecimals" => 18
      }

      md = Models.parse_market_data("ETH", raw)

      assert md.asset == "ETH"
      assert md.funding == "0.0000125"
      assert md.mark_px == "2800.0"
      assert md.oracle_px == "2800.5"
      assert md.sz_decimals == 18
      assert md.impact_pxs == ["2799.0", "2801.0"]
    end
  end
end
