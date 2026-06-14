defmodule Lux.Prisms.Hyperliquid.IntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  @test_address "0x0403369c02199a0cb827f4d6492927e9fa5668d5"

  describe "HyperliquidTokenInfoPrism" do
    test "fetches real token prices" do
      {:ok, result} = Lux.Prisms.Hyperliquid.HyperliquidTokenInfoPrism.run(%{})
      assert result.status == "success" or Map.has_key?(result, :prices)
      assert is_map(result.prices)
      assert Map.has_key?(result.prices, "BTC") or Map.has_key?(result.prices, "ETH")
    end
  end

  describe "HyperliquidUserStatePrism" do
    test "fetches user state for address" do
      {:ok, result} = Lux.Prisms.Hyperliquid.HyperliquidUserStatePrism.run(%{
        address: @test_address
      })
      assert result.status == "success"
      assert is_map(result.user_state)
    end
  end

  describe "HyperliquidOpenOrdersPrism" do
    test "fetches open orders for address" do
      {:ok, result} = Lux.Prisms.Hyperliquid.HyperliquidOpenOrdersPrism.run(%{
        address: @test_address
      })
      assert result.status == "success"
      assert is_list(result.open_orders)
    end
  end

  describe "HyperliquidLiquidationPrism" do
    test "monitors liquidation risk" do
      {:ok, result} = Lux.Prisms.Hyperliquid.HyperliquidLiquidationPrism.run(%{
        address: @test_address,
        risk_threshold: 0.1
      })
      assert result.status == "success"
      assert is_list(result.at_risk_positions)
      assert is_list(result.safe_positions)
    end
  end

  describe "HyperliquidPnlPrism" do
    test "fetches pnl data" do
      {:ok, result} = Lux.Prisms.Hyperliquid.HyperliquidPnlPrism.run(%{
        address: @test_address
      })
      assert result.status == "success"
      assert is_map(result.pnl_data)
      assert Map.has_key?(result.pnl_data, :positions)
    end
  end

  describe "HyperliquidRiskAssessmentPrism" do
    test "calculates risk for proposed trade" do
      {:ok, token_result} = Lux.Prisms.Hyperliquid.HyperliquidTokenInfoPrism.run(%{})
      {:ok, state_result} = Lux.Prisms.Hyperliquid.HyperliquidUserStatePrism.run(%{
        address: @test_address
      })

      {:ok, result} = Lux.Prisms.Hyperliquid.HyperliquidRiskAssessmentPrism.run(%{
        portfolio: state_result.user_state,
        market_data: token_result.prices,
        proposed_trade: %{coin: "ETH", sz: 0.01, limit_px: 2800.0, is_buy: true}
      })

      assert is_float(result.position_size_ratio)
      assert is_float(result.leverage)
      assert is_float(result.liquidation_risk)
    end
  end
end