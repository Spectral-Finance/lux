defmodule Lux.Trading.Hyperliquid.MarginControllerTest do
  use ExUnit.Case, async: true

  alias Lux.Trading.Hyperliquid.MarginController

  describe "max_leverage_for/1" do
    test "returns expected max leverage tiers" do
      assert MarginController.max_leverage_for("BTC") == 50
      assert MarginController.max_leverage_for("ETH") == 50
      assert MarginController.max_leverage_for("SOL") == 20
      assert MarginController.max_leverage_for("UNKNOWN") == 10
    end
  end

  describe "evaluate_account_margin/2" do
    test "evaluates healthy account margin" do
      positions = [
        %{notional: 5000.0, leverage: 10, unrealized_pnl: 100.0}
      ]

      result = MarginController.evaluate_account_margin(2000.0, positions)
      # Equity = 2000 + 100 = 2100
      assert result.account_equity == 2100.0
      assert result.total_notional == 5000.0
      assert result.initial_margin_used == 500.0
      assert result.free_collateral == 1600.0
      assert result.margin_ratio < 10.0
      assert result.margin_call? == false
    end
  end

  describe "validate_leverage/2" do
    test "validates within allowable bounds" do
      assert {:ok, 25} = MarginController.validate_leverage("BTC", 25)
      assert {:error, {:leverage_exceeds_maximum, 20}} = MarginController.validate_leverage("SOL", 30)
      assert {:error, :leverage_below_minimum} = MarginController.validate_leverage("BTC", 0)
    end
  end
end
