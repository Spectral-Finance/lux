defmodule Lux.Lenses.Hyperliquid.RiskMonitoringLensTest do
  use UnitCase, async: true

  alias Lux.Lenses.Hyperliquid.RiskMonitoringLens

  describe "calculate_risk_metrics/1" do
    test "calculates metrics for empty portfolio" do
      data = %{
        "assetPositions" => [],
        "crossMarginSummary" => %{
          "accountValue" => "10000.0",
          "totalNtlPos" => "0.0",
          "totalMarginUsed" => "0.0"
        }
      }

      result = RiskMonitoringLens.calculate_risk_metrics(data)

      assert result.exposure.exposure_ratio == 0.0
      assert result.concentration.num_active_positions == 0
      assert result.risk_score >= 0
    end

    test "calculates exposure for single position" do
      data = %{
        "assetPositions" => [
          %{
            "position" => %{
              "coin" => "ETH",
              "size" => "1.0",
              "positionValue" => "2800.0"
            }
          }
        ],
        "crossMarginSummary" => %{
          "accountValue" => "10000.0",
          "totalNtlPos" => "2800.0",
          "totalMarginUsed" => "1000.0"
        }
      }

      result = RiskMonitoringLens.calculate_risk_metrics(data)

      assert result.exposure.gross_exposure == "2800.0"
      assert result.exposure.exposure_ratio == 0.28
      assert result.exposure.largest_position_ratio == 0.28
    end

    test "calculates concentration metrics" do
      data = %{
        "assetPositions" => [
          %{
            "position" => %{
              "coin" => "ETH",
              "size" => "1.0",
              "positionValue" => "5000.0"
            }
          },
          %{
            "position" => %{
              "coin" => "BTC",
              "size" => "0.1",
              "positionValue" => "10000.0"
            }
          }
        ],
        "crossMarginSummary" => %{
          "accountValue" => "50000.0",
          "totalNtlPos" => "15000.0",
          "totalMarginUsed" => "5000.0"
        }
      }

      result = RiskMonitoringLens.calculate_risk_metrics(data)

      assert result.concentration.num_active_positions == 2
      assert result.concentration.herfindahl_index > 0
      assert result.concentration.top_asset_weight > 0
    end

    test "generates alerts for high exposure" do
      data = %{
        "assetPositions" => [
          %{
            "position" => %{
              "coin" => "ETH",
              "size" => "10.0",
              "positionValue" => "50000.0"
            }
          }
        ],
        "crossMarginSummary" => %{
          "accountValue" => "10000.0",
          "totalNtlPos" => "50000.0",
          "totalMarginUsed" => "10000.0"
        }
      }

      result = RiskMonitoringLens.calculate_risk_metrics(data)

      high_exposure_alerts =
        Enum.filter(result.alerts, fn alert -> alert.type == "high_exposure" end)

      assert length(high_exposure_alerts) > 0
    end

    test "calculates risk score based on multiple factors" do
      data = %{
        "assetPositions" => [
          %{
            "position" => %{
              "coin" => "ETH",
              "size" => "2.0",
              "positionValue" => "5600.0"
            }
          }
        ],
        "crossMarginSummary" => %{
          "accountValue" => "10000.0",
          "totalNtlPos" => "5600.0",
          "totalMarginUsed" => "2000.0"
        }
      }

      result = RiskMonitoringLens.calculate_risk_metrics(data)

      assert result.risk_score >= 0
      assert result.risk_score <= 1.0
    end
  end
end
