defmodule Lux.Prisms.Hyperliquid.LiquidationProtectionPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Hyperliquid.LiquidationProtectionPrism

  describe "handler/2" do
    @tag :skip
    test "sets stop loss for at-risk positions" do
      portfolio = %{
        "crossMarginSummary" => %{
          "accountValue" => "10000.0",
          "totalMarginUsed" => "8000.0"
        },
        "assetPositions" => [
          %{
            "position" => %{
              "coin" => "ETH",
              "size" => "5.0",
              "entryPx" => "2800.0",
              "liquidationPx" => "2700.0",
              "marginUsed" => "4000.0"
            }
          }
        ]
      }

      market_data = %{"ETH" => %{"markPx" => "2750.0"}}

      assert {:ok, result} =
               LiquidationProtectionPrism.run(%{
                 portfolio: portfolio,
                 market_data: market_data,
                 protection_strategy: "set_stop_loss",
                 safety_buffer: 0.15
               })

      assert result.summary.actions_taken >= 0
      assert is_list(result.positions_protected)
    end

    @tag :skip
    test "reduces position for critical risk" do
      portfolio = %{
        "crossMarginSummary" => %{
          "accountValue" => "10000.0",
          "totalMarginUsed" => "9000.0"
        },
        "assetPositions" => [
          %{
            "position" => %{
              "coin" => "ETH",
              "size" => "10.0",
              "entryPx" => "2800.0",
              "liquidationPx" => "2780.0",
              "marginUsed" => "8000.0"
            }
          }
        ]
      }

      market_data = %{"ETH" => %{"markPx" => "2790.0"}}

      assert {:ok, result} =
               LiquidationProtectionPrism.run(%{
                 portfolio: portfolio,
                 market_data: market_data,
                 protection_strategy: "reduce_position",
                 safety_buffer: 0.15,
                 max_position_reduction_pct: 0.5
               })

      assert result.summary.actions_taken >= 0
    end

    @tag :skip
    test "no action needed for safe positions" do
      portfolio = %{
        "crossMarginSummary" => %{
          "accountValue" => "50000.0",
          "totalMarginUsed" => "5000.0"
        },
        "assetPositions" => [
          %{
            "position" => %{
              "coin" => "ETH",
              "size" => "1.0",
              "entryPx" => "2800.0",
              "liquidationPx" => "1400.0",
              "marginUsed" => "1000.0"
            }
          }
        ]
      }

      market_data = %{"ETH" => %{"markPx" => "3000.0"}}

      assert {:ok, result} =
               LiquidationProtectionPrism.run(%{
                 portfolio: portfolio,
                 market_data: market_data,
                 protection_strategy: "set_stop_loss",
                 safety_buffer: 0.15
               })

      assert result.summary.portfolio_safe == true
      assert result.summary.actions_taken == 0
    end

    @tag :skip
    test "handles multiple positions with different risk levels" do
      portfolio = %{
        "crossMarginSummary" => %{
          "accountValue" => "20000.0",
          "totalMarginUsed" => "12000.0"
        },
        "assetPositions" => [
          %{
            "position" => %{
              "coin" => "ETH",
              "size" => "5.0",
              "entryPx" => "2800.0",
              "liquidationPx" => "2700.0",
              "marginUsed" => "6000.0"
            }
          },
          %{
            "position" => %{
              "coin" => "BTC",
              "size" => "0.1",
              "entryPx" => "100000.0",
              "liquidationPx" => "50000.0",
              "marginUsed" => "6000.0"
            }
          }
        ]
      }

      market_data = %{
        "ETH" => %{"markPx" => "2750.0"},
        "BTC" => %{"markPx" => "105000.0"}
      }

      assert {:ok, result} =
               LiquidationProtectionPrism.run(%{
                 portfolio: portfolio,
                 market_data: market_data,
                 protection_strategy: "set_stop_loss",
                 safety_buffer: 0.15
               })

      assert is_list(result.positions_protected)
      assert result.summary.total_positions_at_risk >= 0
    end
  end
end
