defmodule Lux.Integration.Hyperliquid.TradingOperationsTest do
  use IntegrationCase, async: false

  @moduledoc """
  Integration tests for Hyperliquid perpetual trading operations.

  These tests verify the end-to-end workflow of the perpetual trading system,
  including position tracking, risk assessment, and order execution flow.
  """

  alias Lux.Lenses.Hyperliquid.PositionTrackerLens
  alias Lux.Lenses.Hyperliquid.RiskMonitoringLens
  alias Lux.Lenses.Hyperliquid.LiquidationMonitorLens
  alias Lux.Lenses.Hyperliquid.MarketDataLens

  describe "position tracking workflow" do
    test "tracks positions through complete lifecycle" do
      # Simulate portfolio state transitions
      initial_state = %{
        "assetPositions" => [],
        "crossMarginSummary" => %{
          "accountValue" => "10000.0",
          "totalMarginUsed" => "0.0",
          "totalNtlPos" => "0.0"
        }
      }

      # Process initial state
      initial_result = PositionTrackerLens.process_positions(initial_state)
      assert initial_result.summary.total_positions == 0

      # Simulate opening a position
      open_position_state = %{
        "assetPositions" => [
          %{
            "position" => %{
              "coin" => "ETH",
              "size" => "1.0",
              "entryPx" => "2800.0",
              "markPx" => "2850.0",
              "returnOnEquity" => "0.05",
              "leverage" => "2.0",
              "liquidationPx" => "1400.0",
              "marginUsed" => "1000.0",
              "positionValue" => "2850.0"
            }
          }
        ],
        "crossMarginSummary" => %{
          "accountValue" => "10050.0",
          "totalMarginUsed" => "1000.0",
          "totalNtlPos" => "2850.0"
        }
      }

      open_result = PositionTrackerLens.process_positions(open_position_state)
      assert open_result.summary.total_positions == 1
      assert hd(open_result.positions).coin == "ETH"

      # Simulate position growth
      grown_state = %{
        "assetPositions" => [
          %{
            "position" => %{
              "coin" => "ETH",
              "size" => "1.0",
              "entryPx" => "2800.0",
              "markPx" => "3100.0",
              "returnOnEquity" => "0.15",
              "leverage" => "2.0",
              "liquidationPx" => "1500.0",
              "marginUsed" => "1000.0",
              "positionValue" => "3100.0"
            }
          }
        ],
        "crossMarginSummary" => %{
          "accountValue" => "10300.0",
          "totalMarginUsed" => "1000.0",
          "totalNtlPos" => "3100.0"
        }
      }

      grown_result = PositionTrackerLens.process_positions(grown_state)
      assert grown_result.summary.total_unrealized_pnl == "300.0"
    end

    test "monitors risk across position changes" do
      portfolio = %{
        "assetPositions" => [
          %{
            "position" => %{
              "coin" => "ETH",
              "size" => "2.0",
              "positionValue" => "5600.0"
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
          "totalNtlPos" => "15600.0",
          "totalMarginUsed" => "8000.0"
        }
      }

      result = RiskMonitoringLens.calculate_risk_metrics(portfolio)

      # Verify risk metrics are calculated
      assert result.exposure.gross_exposure == "15600.0"
      assert result.exposure.exposure_ratio == 0.312
      assert result.concentration.num_active_positions == 2
      assert result.risk_score >= 0
    end
  end

  describe "liquidation monitoring workflow" do
    test "detects and alerts on liquidation risk" do
      portfolio = %{
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

      result = LiquidationMonitorLens.monitor_liquidation_risk(portfolio)

      # Position should be flagged as at-risk
      pos = hd(result.positions)
      assert pos.warning_level in ["danger", "warning", "caution"]
      assert pos.distance_to_liquidation < 0.25
    end

    test "confirms safe positions" do
      portfolio = %{
        "assetPositions" => [
          %{
            "position" => %{
              "coin" => "ETH",
              "size" => "1.0",
              "entryPx" => "2800.0",
              "liquidationPx" => "1400.0",
              "markPx" => "3000.0",
              "marginUsed" => "1000.0",
              "positionValue" => "3000.0"
            }
          }
        ],
        "crossMarginSummary" => %{
          "accountValue" => "20000.0",
          "totalMarginUsed" => "1000.0"
        }
      }

      result = LiquidationMonitorLens.monitor_liquidation_risk(portfolio)

      pos = hd(result.positions)
      assert pos.warning_level == "safe"
      assert result.summary.total_positions_at_risk == 0
    end
  end

  describe "market data processing" do
    test "processes multi-asset market data" do
      meta = %{
        "universe" => [
          %{"name" => "BTC", "szDecimals" => 5},
          %{"name" => "ETH", "szDecimals" => 6},
          %{"name" => "SOL", "szDecimals" => 3}
        ]
      }

      asset_ctxs = [
        %{
          "markPx" => "104050.0",
          "midPx" => "104045.0",
          "funding" => "0.0000125",
          "openInterest" => "50000.0",
          "dayNtlVlm" => "125000000.0",
          "prevDayPx" => "103500.0",
          "oraclePx" => "104000.0",
          "impactPxs" => ["104040.0", "104050.0"]
        },
        %{
          "markPx" => "2800.0",
          "midPx" => "2799.5",
          "funding" => "0.000008",
          "openInterest" => "30000.0",
          "dayNtlVlm" => "50000000.0",
          "prevDayPx" => "2750.0",
          "oraclePx" => "2798.0",
          "impactPxs" => ["2799.0", "2800.0"]
        },
        %{
          "markPx" => "180.0",
          "midPx" => "179.9",
          "funding" => "0.000015",
          "openInterest" => "10000.0",
          "dayNtlVlm" => "20000000.0",
          "prevDayPx" => "175.0",
          "oraclePx" => "179.5",
          "impactPxs" => ["179.8", "180.0"]
        }
      ]

      result = MarketDataLens.process_market_data([meta, asset_ctxs])

      assert map_size(result.markets) == 3
      assert result.summary.total_markets == 3
      assert result.summary.total_open_interest == "90000.0"
      assert result.summary.total_day_volume == "195000000.0"
    end
  end
end
