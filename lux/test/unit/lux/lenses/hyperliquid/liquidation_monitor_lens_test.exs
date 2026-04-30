defmodule Lux.Lenses.Hyperliquid.LiquidationMonitorLensTest do
  use UnitCase, async: true

  alias Lux.Lenses.Hyperliquid.LiquidationMonitorLens

  describe "monitor_liquidation_risk/1" do
    test "monitors safe positions" do
      data = %{
        "assetPositions" => [
          %{
            "position" => %{
              "coin" => "ETH",
              "size" => "1.0",
              "entryPx" => "2800.0",
              "liquidationPx" => "1400.0",
              "markPx" => "2950.0",
              "marginUsed" => "1000.0",
              "positionValue" => "2950.0"
            }
          }
        ],
        "crossMarginSummary" => %{
          "accountValue" => "10000.0",
          "totalMarginUsed" => "1000.0"
        }
      }

      result = LiquidationMonitorLens.monitor_liquidation_risk(data)

      assert length(result.positions) == 1
      pos = hd(result.positions)
      assert pos.coin == "ETH"
      assert pos.warning_level == "safe"
      assert pos.distance_to_liquidation > 0.4
    end

    test "identifies dangerous positions" do
      data = %{
        "assetPositions" => [
          %{
            "position" => %{
              "coin" => "ETH",
              "size" => "5.0",
              "entryPx" => "2800.0",
              "liquidationPx" => "2700.0",
              "markPx" => "2750.0",
              "marginUsed" => "4000.0",
              "positionValue" => "13750.0"
            }
          }
        ],
        "crossMarginSummary" => %{
          "accountValue" => "10000.0",
          "totalMarginUsed" => "4000.0"
        }
      }

      result = LiquidationMonitorLens.monitor_liquidation_risk(data)

      pos = hd(result.positions)
      assert pos.warning_level in ["danger", "warning"]
      assert pos.distance_to_liquidation < 0.15
    end

    test "handles nil liquidation price" do
      data = %{
        "assetPositions" => [
          %{
            "position" => %{
              "coin" => "SOL",
              "size" => "10.0",
              "entryPx" => "150.0",
              "liquidationPx" => "nil",
              "markPx" => "160.0",
              "marginUsed" => "500.0",
              "positionValue" => "1600.0"
            }
          }
        ],
        "crossMarginSummary" => %{
          "accountValue" => "5000.0",
          "totalMarginUsed" => "500.0"
        }
      }

      result = LiquidationMonitorLens.monitor_liquidation_risk(data)

      pos = hd(result.positions)
      assert pos.warning_level == "safe"
      assert pos.distance_to_liquidation == 1.0
    end

    test "generates liquidation alerts" do
      data = %{
        "assetPositions" => [
          %{
            "position" => %{
              "coin" => "ETH",
              "size" => "5.0",
              "entryPx" => "2800.0",
              "liquidationPx" => "2750.0",
              "markPx" => "2780.0",
              "marginUsed" => "4000.0",
              "positionValue" => "13900.0"
            }
          }
        ],
        "crossMarginSummary" => %{
          "accountValue" => "10000.0",
          "totalMarginUsed" => "4000.0"
        }
      }

      result = LiquidationMonitorLens.monitor_liquidation_risk(data)

      danger_alerts = Enum.filter(result.alerts, fn a -> a.type == "liquidation_danger" end)
      assert length(danger_alerts) > 0
    end

    test "calculates overall margin health" do
      data = %{
        "assetPositions" => [],
        "crossMarginSummary" => %{
          "accountValue" => "10000.0",
          "totalMarginUsed" => "2000.0"
        }
      }

      result = LiquidationMonitorLens.monitor_liquidation_risk(data)

      assert result.summary.overall_margin_health == 0.8
    end
  end
end
