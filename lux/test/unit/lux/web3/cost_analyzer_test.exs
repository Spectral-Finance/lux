defmodule Lux.Web3.Gas.CostAnalyzerTest do
  use UnitAPICase, async: true

  alias Lux.Web3.Gas.CostAnalyzer

  describe "generate_report/2" do
    test "generates report from transaction records" do
      transactions = [
        %{gas_used: 21_000, gas_price: 30_000_000_000, type: "transfer"},
        %{gas_used: 65_000, gas_price: 35_000_000_000, type: "swap"},
        %{gas_used: 150_000, gas_price: 40_000_000_000, type: "mint"}
      ]

      assert {:ok, report} = CostAnalyzer.generate_report(transactions, "2025-06")

      assert report.period == "2025-06"
      assert report.total_transactions == 3
      assert report.total_gas_used == 236_000
      assert report.total_cost_eth > 0
      assert report.average_gas_price > 0
      assert report.average_cost_per_tx_eth > 0
      assert report.savings_from_optimization >= 0
      assert length(report.breakdown_by_type) == 3
    end

    test "rejects empty transaction list" do
      assert {:error, :empty_report} = CostAnalyzer.generate_report([], "2025-06")
    end

    test "breakdown contains correct type counts" do
      transactions = [
        %{gas_used: 21_000, gas_price: 30_000_000_000, type: "transfer"},
        %{gas_used: 21_000, gas_price: 30_000_000_000, type: "transfer"},
        %{gas_used: 65_000, gas_price: 35_000_000_000, type: "swap"}
      ]

      assert {:ok, report} = CostAnalyzer.generate_report(transactions, "test")
      types = Enum.map(report.breakdown_by_type, & &1.type)
      assert "transfer" in types
      assert "swap" in types
    end
  end

  describe "compare_costs/3" do
    test "calculates savings when optimal is cheaper" do
      result = CostAnalyzer.compare_costs(21_000, 40_000_000_000, 30_000_000_000)
      assert result.current_cost_wei == 840_000_000_000_000
      assert result.optimal_cost_wei == 630_000_000_000_000
      assert result.savings_wei == 210_000_000_000_000
      assert result.savings_pct > 0
    end

    test "returns zero savings when optimal equals current" do
      result = CostAnalyzer.compare_costs(21_000, 30_000_000_000, 30_000_000_000)
      assert result.savings_wei == 0
      assert result.savings_pct == 0.0
    end
  end
end
