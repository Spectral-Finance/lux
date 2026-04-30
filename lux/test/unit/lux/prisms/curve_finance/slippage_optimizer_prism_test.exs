defmodule Lux.Prisms.CurveFinance.SlippageOptimizerPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.CurveFinance.SlippageOptimizerPrism

  describe "run/1" do
    test "finds optimal swap route" do
      params = %{from: "USDC", to: "DAI", amount: 100_000}
      assert {:ok, result} = SlippageOptimizerPrism.run(params)
      assert result.slippage >= 0
      assert result.estimated_output > 0
    end

    test "respects max slippage threshold" do
      params = %{from: "USDC", to: "DAI", amount: 10_000, max_slippage: 0.001}
      assert {:ok, result} = SlippageOptimizerPrism.run(params)
      assert result.route != nil
    end
  end

  describe "split_order/1" do
    test "splits large order into smaller trades" do
      params = %{from: "USDC", to: "DAI", amount: 1_000_000, max_single_trade: 100_000}
      assert {:ok, result} = SlippageOptimizerPrism.split_order(params)
      assert result.num_splits > 1
    end
  end
end
