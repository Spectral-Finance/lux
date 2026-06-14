defmodule Lux.Prisms.Hyperliquid.HyperliquidRiskAssessmentPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Hyperliquid.HyperliquidRiskAssessmentPrism

  @portfolio %{
    "assetPositions" => [
      %{
        "position" => %{
          "coin" => "ETH",
          "positionValue" => "2000.0",
          "returnOnEquity" => "0.15",
          "liquidationPx" => "1400.0",
          "marginUsed" => "1000.0",
          "entryPx" => "2800.0",
          "leverage" => %{"value" => "2", "type" => "cross"},
          "size" => "1.0"
        }
      }
    ],
    "crossMarginSummary" => %{
      "accountValue" => "10000.0",
      "totalMarginUsed" => "1000.0",
      "totalNtlPos" => "2000.0",
      "totalRawUsd" => "10000.0"
    }
  }

  @market_data %{
    "ETH" => %{"markPx" => "2800.0", "funding" => "0.0001"}
  }

  @proposed_trade %{
    coin: "ETH",
    sz: 0.1,
    limit_px: 2800.0,
    is_buy: true
  }

  describe "handler/2" do
    test "calculates risk metrics for valid trade" do
      {:ok, result} = HyperliquidRiskAssessmentPrism.run(%{
        portfolio: @portfolio,
        market_data: @market_data,
        proposed_trade: @proposed_trade
      })

      assert is_float(result.position_size_ratio)
      assert is_float(result.leverage)
      assert is_float(result.portfolio_concentration)
      assert is_float(result.liquidation_risk)
      assert is_float(result.unrealized_pnl)
    end

    test "returns zero metrics for new position" do
      portfolio = Map.put(@portfolio, "assetPositions", [])
      {:ok, result} = HyperliquidRiskAssessmentPrism.run(%{
        portfolio: portfolio,
        market_data: @market_data,
        proposed_trade: @proposed_trade
      })

      assert result.portfolio_concentration == 0.0
      assert result.liquidation_risk == 0.0
      assert result.unrealized_pnl == 0.0
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = HyperliquidRiskAssessmentPrism.view()
      assert prism.input_schema.required == ["portfolio", "market_data", "proposed_trade"]
    end

    test "validates output schema" do
      prism = HyperliquidRiskAssessmentPrism.view()
      required = prism.output_schema.required
      assert "position_size_ratio" in required
      assert "leverage" in required
      assert "liquidation_risk" in required
    end
  end
end
