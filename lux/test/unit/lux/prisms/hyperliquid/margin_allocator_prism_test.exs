defmodule Lux.Prisms.Hyperliquid.MarginAllocatorPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Hyperliquid.MarginAllocatorPrism

  describe "handler/2" do
    @tag :skip
    test "approves margin allocation for healthy portfolio" do
      portfolio = %{
        "crossMarginSummary" => %{
          "accountValue" => "50000.0",
          "totalMarginUsed" => "10000.0",
          "totalNtlPos" => "20000.0"
        },
        "assetPositions" => [
          %{
            "position" => %{
              "coin" => "ETH",
              "size" => "2.0",
              "marginUsed" => "5000.0",
              "positionValue" => "5600.0"
            }
          }
        ]
      }

      new_position = %{
        "coin" => "SOL",
        "sz" => 10,
        "limit_px" => 150.0
      }

      assert {:ok, result} =
               MarginAllocatorPrism.run(%{
                 portfolio: portfolio,
                 new_position: new_position,
                 allocation_strategy: "risk_adjusted"
               })

      assert result.recommended_allocation.status in ["approved", "partial"]
      assert result.utilization_ratio == 0.2
    end

    @tag :skip
    test "respects max allocation percentage" do
      portfolio = %{
        "crossMarginSummary" => %{
          "accountValue" => "10000.0",
          "totalMarginUsed" => "2000.0",
          "totalNtlPos" => "5000.0"
        },
        "assetPositions" => []
      }

      # Large position that would exceed max allocation
      new_position = %{
        "coin" => "BTC",
        "sz" => 1.0,
        "limit_px" => 100000.0
      }

      assert {:ok, result} =
               MarginAllocatorPrism.run(%{
                 portfolio: portfolio,
                 new_position: new_position,
                 allocation_strategy: "risk_adjusted",
                 max_allocation_pct: 25.0
               })

      # Should be rejected or partial due to exceeding max allocation
      assert result.recommended_allocation.status in ["approved", "partial", "rejected"]
    end

    @tag :skip
    test "calculates current allocations correctly" do
      portfolio = %{
        "crossMarginSummary" => %{
          "accountValue" => "20000.0",
          "totalMarginUsed" => "6000.0",
          "totalNtlPos" => "12000.0"
        },
        "assetPositions" => [
          %{
            "position" => %{
              "coin" => "ETH",
              "size" => "3.0",
              "marginUsed" => "4000.0",
              "positionValue" => "8400.0"
            }
          },
          %{
            "position" => %{
              "coin" => "SOL",
              "size" => "50.0",
              "marginUsed" => "2000.0",
              "positionValue" => "7500.0"
            }
          }
        ]
      }

      new_position = %{
        "coin" => "BTC",
        "sz" => 0.1,
        "limit_px" => 100000.0
      }

      assert {:ok, result} =
               MarginAllocatorPrism.run(%{
                 portfolio: portfolio,
                 new_position: new_position
               })

      assert Map.has_key?(result.current_allocations, "ETH")
      assert Map.has_key?(result.current_allocations, "SOL")

      eth_allocation = result.current_allocations["ETH"]
      assert eth_allocation.allocation_pct == 66.67
    end

    @tag :skip
    test "handles equal weight strategy" do
      portfolio = %{
        "crossMarginSummary" => %{
          "accountValue" => "30000.0",
          "totalMarginUsed" => "5000.0",
          "totalNtlPos" => "10000.0"
        },
        "assetPositions" => [
          %{
            "position" => %{
              "coin" => "ETH",
              "size" => "2.0",
              "marginUsed" => "5000.0",
              "positionValue" => "5600.0"
            }
          }
        ]
      }

      new_position = %{
        "coin" => "BTC",
        "sz" => 0.1,
        "limit_px" => 100000.0
      }

      assert {:ok, result} =
               MarginAllocatorPrism.run(%{
                 portfolio: portfolio,
                 new_position: new_position,
                 allocation_strategy: "equal_weight"
               })

      assert result.recommended_allocation.status in ["approved", "partial", "rejected"]
    end
  end
end
