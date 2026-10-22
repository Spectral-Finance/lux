defmodule Lux.Prisms.Hyperliquid.HyperliquidPositionManagementPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Hyperliquid.HyperliquidPositionManagementPrism

  describe "schema validation" do
    test "view/0 returns valid prism struct" do
      prism = HyperliquidPositionManagementPrism.view()
      assert prism.name == "Hyperliquid Position Management"
      assert prism.input_schema.required == ["positions", "account_value"]
      assert prism.output_schema.required == ["status", "margin_ratio", "risk_level"]
    end
  end

  describe "handler/2" do
    test "classifies critical risk when margin ratio drops below threshold" do
      input = %{
        positions: [
          %{
            "coin" => "ETH",
            "size" => 2.0,
            "entryPx" => 2500.0,
            "liquidationPx" => 2480.0
          }
        ],
        account_value: 500.0,
        total_ntl_pos: 10000.0,
        margin_threshold: 0.1
      }

      assert {:ok, result} = HyperliquidPositionManagementPrism.handler(input, %{})

      assert result.status == "success"
      assert result.margin_ratio == 0.05
      assert result.risk_level == "critical"
      assert "reduce_position" in result.recommended_actions
      assert "add_margin" in result.recommended_actions
      assert result.position_count == 1
    end

    test "classifies low risk for well-margined position" do
      input = %{
        positions: [
          %{
            "coin" => "BTC",
            "size" => 0.1,
            "entryPx" => 60000.0,
            "liquidationPx" => 40000.0
          }
        ],
        account_value: 10000.0,
        total_ntl_pos: 6000.0,
        margin_threshold: 0.1
      }

      assert {:ok, result} = HyperliquidPositionManagementPrism.handler(input, %{})

      assert result.status == "success"
      assert result.risk_level == "low"
      assert result.recommended_actions == []
      assert result.liquidation_distance > 0.3
    end

    test "handles empty positions portfolio safely" do
      input = %{
        positions: [],
        account_value: 5000.0,
        total_ntl_pos: 0.0
      }

      assert {:ok, result} = HyperliquidPositionManagementPrism.handler(input, %{})

      assert result.status == "success"
      assert result.margin_ratio == 1.0
      assert result.risk_level == "low"
      assert result.position_count == 0
    end
  end
end
