defmodule Lux.Web3.GasTransactionManagementIntegrationTest do
  use IntegrationCase, async: false

  alias Lux.Web3.Gas

  describe "full gas optimization workflow" do
    test "predicts gas prices, creates batch, analyzes MEV, simulates, and generates report" do
      # Step 1: Predict gas prices
      Application.put_env(:lux, :gas_prediction_blocks, [
        %{"baseFeePerGas" => "0x5d21dba00"},
        %{"baseFeePerGas" => "0x5b9a8d400"},
        %{"baseFeePerGas" => "0x5c8e3a800"}
      ])

      assert {:ok, recommendation} = Gas.predict_price(network: "mainnet")
      assert recommendation.base_fee > 0
      assert recommendation.slow.max_fee_per_gas < recommendation.standard.max_fee_per_gas

      # Step 2: Create a transaction batch
      transactions = [
        %{nonce: 42, to: "0x1234567890abcdef1234567890abcdef12345678", data: "0xa9059cbb0000", gas_limit: 21_000, max_fee_per_gas: 30_000_000_000},
        %{nonce: 43, to: "0x7a250d5c35b", data: "0x38ed17390000", gas_limit: 150_000, max_fee_per_gas: 35_000_000_000}
      ]

      assert {:ok, batch} = Gas.create_batch(transactions, nonce: 42)
      assert batch.estimated_total_gas > 0
      assert batch.estimated_total_cost_eth > 0

      # Step 3: Analyze MEV risk
      swap_tx = %{to: "0x7a250d5c35b", value: 5_000_000_000_000_000_000, data: "0x38ed17390000"}
      assert {:ok, mev_analysis} = Gas.analyze_mev(swap_tx)
      assert mev_analysis.risk_level in [:medium, :high]
      assert mev_analysis.recommended_private_relay == true

      # Step 4: Simulate a transaction
      sim_tx = %{from: "0x1234567890abcdef1234567890abcdef12345678", to: "0xabcdef1234567890abcdef1234567890abcdef12", data: "0xa9059cbb", value: 0, network: "mainnet"}
      assert {:ok, sim_result} = Gas.simulate(sim_tx)
      assert sim_result.success == true
      assert sim_result.estimated_gas > 0

      # Step 5: Pre-flight check
      assert {:ok, %{passed: true}} = Gas.preflight_check(sim_tx)

      # Step 6: Speed-up replacement
      original = %{hash: "0xtx123", nonce: 42, max_fee_per_gas: 30_000_000_000}
      assert {:ok, replacement} = Gas.speed_up(original, %{max_fee_per_gas: 40_000_000_000, max_priority_fee_per_gas: 2_000_000_000})
      assert replacement.replacement_type == :speed_up

      # Step 7: Cancel replacement
      assert {:ok, cancel} = Gas.cancel("0xtx123", 42, 50_000_000_000, 3_000_000_000)
      assert cancel.replacement_type == :cancel

      # Step 8: Cost report
      cost_txs = [
        %{gas_used: 21_000, gas_price: 30_000_000_000, type: "transfer"},
        %{gas_used: 150_000, gas_price: 35_000_000_000, type: "swap"}
      ]
      assert {:ok, report} = Gas.cost_report(cost_txs, "2025-06")
      assert report.total_transactions == 2
      assert report.total_gas_used == 171_000
      assert report.total_cost_eth > 0
    end
  end
end
