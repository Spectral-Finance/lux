defmodule Lux.Prisms.Hyperliquid.LeverageManagerPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Hyperliquid.LeverageManagerPrism

  describe "handler/2" do
    @tag :skip
    test "calculates recommended leverage for conservative risk tolerance" do
      portfolio = %{
        "crossMarginSummary" => %{
          "accountValue" => "10000.0",
          "totalNtlPos" => "2000.0"
        },
        "assetPositions" => []
      }

      position = %{
        "coin" => "ETH",
        "sz" => 0.5,
        "limit_px" => 2800.0
      }

      market_data = %{"ETH" => %{"markPx" => "2800.0"}}

      assert {:ok, result} =
               LeverageManagerPrism.run(%{
                 portfolio: portfolio,
                 proposed_position: position,
                 market_data: market_data,
                 risk_tolerance: "conservative"
               })

      assert result.recommended_leverage > 0
      assert result.max_safe_leverage == 3.0
      assert result.current_leverage == 0.2
    end

    @tag :skip
    test "calculates leverage for aggressive risk tolerance" do
      portfolio = %{
        "crossMarginSummary" => %{
          "accountValue" => "50000.0",
          "totalNtlPos" => "10000.0"
        },
        "assetPositions" => []
      }

      position = %{
        "coin" => "BTC",
        "sz" => 0.1,
        "limit_px" => 100000.0
      }

      market_data = %{"BTC" => %{"markPx" => "100000.0"}}

      assert {:ok, result} =
               LeverageManagerPrism.run(%{
                 portfolio: portfolio,
                 proposed_position: position,
                 market_data: market_data,
                 risk_tolerance: "aggressive"
               })

      assert result.max_safe_leverage == 10.0
      assert result.risk_assessment in ["very_low", "low", "moderate", "high", "critical"]
    end

    @tag :skip
    test "validates target leverage against maximum" do
      portfolio = %{
        "crossMarginSummary" => %{
          "accountValue" => "10000.0",
          "totalNtlPos" => "0.0"
        },
        "assetPositions" => []
      }

      position = %{
        "coin" => "ETH",
        "sz" => 1.0,
        "limit_px" => 2800.0
      }

      market_data = %{"ETH" => %{"markPx" => "2800.0"}}

      assert {:ok, result} =
               LeverageManagerPrism.run(%{
                 portfolio: portfolio,
                 proposed_position: position,
                 market_data: market_data,
                 risk_tolerance: "moderate",
                 target_leverage: 15.0
               })

      # Should be capped at max_safe_leverage for moderate (5.0)
      assert result.recommended_leverage <= 5.0
    end

    @tag :skip
    test "assesses risk level correctly" do
      portfolio = %{
        "crossMarginSummary" => %{
          "accountValue" => "10000.0",
          "totalNtlPos" => "8000.0"
        },
        "assetPositions" => [
          %{
            "position" => %{
              "coin" => "ETH",
              "size" => "2.0",
              "positionValue" => "5600.0"
            }
          }
        ]
      }

      position = %{
        "coin" => "BTC",
        "sz" => 0.5,
        "limit_px" => 100000.0
      }

      market_data = %{"BTC" => %{"markPx" => "100000.0"}}

      assert {:ok, result} =
               LeverageManagerPrism.run(%{
                 portfolio: portfolio,
                 proposed_position: position,
                 market_data: market_data,
                 risk_tolerance: "conservative"
               })

      # Large new position should result in higher risk assessment
      assert result.risk_assessment in ["moderate", "high", "critical"]
    end
  end
end
