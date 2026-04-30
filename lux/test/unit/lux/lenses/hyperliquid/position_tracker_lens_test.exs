defmodule Lux.Lenses.Hyperliquid.PositionTrackerLensTest do
  use UnitCase, async: true

  alias Lux.Lenses.Hyperliquid.PositionTrackerLens

  describe "process_positions/1" do
    test "processes empty positions" do
      data = %{
        "assetPositions" => [],
        "crossMarginSummary" => %{
          "accountValue" => "10000.0",
          "totalMarginUsed" => "0.0",
          "totalNtlPos" => "0.0"
        }
      }

      result = PositionTrackerLens.process_positions(data)

      assert result.positions == []
      assert result.summary.total_positions == 0
      assert result.summary.total_unrealized_pnl == "0.0"
      assert result.summary.account_value == "10000.0"
    end

    test "processes single long position" do
      data = %{
        "assetPositions" => [
          %{
            "position" => %{
              "coin" => "ETH",
              "size" => "1.0",
              "entryPx" => "2800.0",
              "markPx" => "2950.0",
              "returnOnEquity" => "0.15",
              "leverage" => "2.0",
              "liquidationPx" => "1400.0",
              "marginUsed" => "1000.0",
              "positionValue" => "2950.0"
            }
          }
        ],
        "crossMarginSummary" => %{
          "accountValue" => "10000.0",
          "totalMarginUsed" => "1000.0",
          "totalNtlPos" => "2950.0"
        }
      }

      result = PositionTrackerLens.process_positions(data)

      assert length(result.positions) == 1
      pos = hd(result.positions)
      assert pos.coin == "ETH"
      assert pos.size == "1.0"
      assert pos.side == "long"
      assert result.summary.total_positions == 1
      assert result.summary.utilization_ratio == "0.1"
    end

    test "processes short position correctly" do
      data = %{
        "assetPositions" => [
          %{
            "position" => %{
              "coin" => "BTC",
              "size" => "-0.5",
              "entryPx" => "100000.0",
              "markPx" => "98000.0",
              "returnOnEquity" => "0.10",
              "leverage" => "3.0",
              "liquidationPx" => "110000.0",
              "marginUsed" => "16000.0",
              "positionValue" => "49000.0"
            }
          }
        ],
        "crossMarginSummary" => %{
          "accountValue" => "50000.0",
          "totalMarginUsed" => "16000.0",
          "totalNtlPos" => "49000.0"
        }
      }

      result = PositionTrackerLens.process_positions(data)

      pos = hd(result.positions)
      assert pos.side == "short"
      assert pos.coin == "BTC"
    end

    test "calculates utilization ratio correctly" do
      data = %{
        "assetPositions" => [],
        "crossMarginSummary" => %{
          "accountValue" => "10000.0",
          "totalMarginUsed" => "3000.0"
        }
      }

      result = PositionTrackerLens.process_positions(data)
      assert result.summary.utilization_ratio == "0.3"
    end

    test "handles zero account value" do
      data = %{
        "assetPositions" => [],
        "crossMarginSummary" => %{
          "accountValue" => "0.0",
          "totalMarginUsed" => "0.0"
        }
      }

      result = PositionTrackerLens.process_positions(data)
      assert result.summary.utilization_ratio == "0"
    end
  end
end
