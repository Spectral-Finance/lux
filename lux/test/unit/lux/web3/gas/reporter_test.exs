defmodule Lux.Web3.Gas.ReporterTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Gas.Reporter

  describe "generate_report/2" do
    test "calculates multi-currency costs and savings accurately" do
      params = %{
        gas_used: 100_000,
        base_fee_gwei: 30.0,
        priority_fee_gwei: 2.0,
        eth_price_usd: 3000.0
      }

      savings = %{
        gas_saved_batching: 21_000,
        access_list_savings: 400,
        gas_refund: 5_000
      }

      report = Reporter.generate_report(params, savings)

      assert report.gas_used == 100_000
      assert report.effective_gas_price_gwei == 32.0
      assert report.total_cost_usd > 0
      assert report.savings_summary.total_gas_saved == 26_400
      assert report.savings_summary.total_usd_saved > 0
    end
  end

  describe "to_markdown/1" do
    test "formats report into markdown text" do
      report = Reporter.generate_report(%{gas_used: 21_000})
      md = Reporter.to_markdown(report)

      assert String.contains?(md, "Gas Cost & Optimization Report")
      assert String.contains?(md, "Gas Consumed")
    end
  end
end
