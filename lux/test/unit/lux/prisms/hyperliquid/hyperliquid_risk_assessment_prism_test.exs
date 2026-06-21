defmodule Lux.Prisms.Hyperliquid.HyperliquidRiskAssessmentPrismTest do
  @moduledoc """
  Test suite for HyperliquidRiskAssessmentPrism.
  """

  use UnitAPICase, async: true

  alias Lux.Prisms.Hyperliquid.HyperliquidRiskAssessmentPrism

  describe "run/1" do
    test "successfully calculates risk metrics" do
      input = %{
        portfolio: %{
          "crossMarginSummary" => %{
            "accountValue" => "10000.0",
            "totalMarginUsed" => "1000.0",
            "totalNtlPos" => "2000.0",
            "totalRawUsd" => "10000.0"
          },
          "assetPositions" => [
            %{
              "type" => "cross",
              "position" => %{
                "coin" => "ETH",
                "positionValue" => "2000.0",
                "returnOnEquity" => "0.15",
                "liquidationPx" => "1400.0"
              }
            }
          ]
        },
        market_data: %{
          "ETH" => %{
            "markPx" => "2800.0"
          }
        },
        proposed_trade: %{
          "coin" => "ETH",
          "sz" => 0.1,
          "limit_px" => 2800.0,
          "is_buy" => true
        }
      }

      assert {:ok, metrics} = HyperliquidRiskAssessmentPrism.run(input)
      assert_in_delta metrics["position_size_ratio"], 0.028, 0.001
      assert_in_delta metrics["leverage"], 0.228, 0.001
      assert_in_delta metrics["portfolio_concentration"], 0.2, 0.001
      assert_in_delta metrics["liquidation_risk"], 0.5, 0.001
      assert_in_delta metrics["unrealized_pnl"], 0.15, 0.001
    end
  end
end
