defmodule Lux.Web3.GasPrismTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.GasOptimizationPrism

  describe "handler/2 with action :predict" do
    test "returns fee recommendation" do
      result = GasOptimizationPrism.handler(%{action: "predict", network: "mainnet"}, nil)
      assert {:ok, %{action: "predict", result: result_map}} = result
      assert is_map(result_map)
      assert result_map[:base_fee] > 0
    end
  end

  describe "handler/2 with action :simulate" do
    test "simulates a transaction" do
      tx = %{from: "0x1234567890abcdef1234567890abcdef12345678", to: "0xabcdef1234567890abcdef1234567890abcdef12", data: "0xa9059cbb", value: 0}

      result = GasOptimizationPrism.handler(%{action: "simulate", transaction: tx, network: "mainnet"}, nil)
      assert {:ok, %{action: "simulate", result: sim_result}} = result
      assert sim_result[:success] == true
    end
  end

  describe "handler/2 with action :mev" do
    test "analyzes MEV risk for DEX swap" do
      tx = %{to: "0x7a250d5c35b", value: 5_000_000_000_000_000_000, data: "0x38ed17390000"}

      result = GasOptimizationPrism.handler(%{action: "mev", transaction: tx}, nil)
      assert {:ok, %{action: "mev", result: mev_result}} = result
      assert mev_result[:risk_level] in [:medium, :high]
    end
  end

  describe "handler/2 with action :batch" do
    test "creates a batch plan" do
      txns = [
        %{nonce: 42, to: "0x1234", data: "0xab", gas_limit: 21_000, max_fee_per_gas: 30_000_000_000},
        %{nonce: 43, to: "0x5678", data: "0xcd", gas_limit: 50_000, max_fee_per_gas: 35_000_000_000}
      ]

      result = GasOptimizationPrism.handler(%{action: "batch", transactions: txns, nonce: 42}, nil)
      assert {:ok, %{action: "batch", result: batch_result}} = result
      assert batch_result[:estimated_total_gas] == 71_000
    end
  end

  describe "handler/2 with action :report" do
    test "generates cost report" do
      txns = [
        %{gas_used: 21_000, gas_price: 30_000_000_000, type: "transfer"},
        %{gas_used: 65_000, gas_price: 35_000_000_000, type: "swap"}
      ]

      result = GasOptimizationPrism.handler(%{action: "report", transactions: txns, period: "2025-06"}, nil)
      assert {:ok, %{action: "report", result: report_result}} = result
      assert report_result[:total_transactions] == 2
    end
  end

  describe "handler/2 with unknown action" do
    test "returns error for unsupported action" do
      result = GasOptimizationPrism.handler(%{action: "unknown_action"}, nil)
      assert {:error, msg} = result
      assert msg =~ "Unknown gas optimization action"
    end
  end
end
