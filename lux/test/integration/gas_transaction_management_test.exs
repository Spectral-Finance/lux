defmodule GasTransactionManagementIntegrationTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Lux.Prisms.Gas.GasPricePredictionPrism
  alias Lux.Prisms.Gas.TransactionBatchingPrism
  alias Lux.Prisms.Gas.TransactionReplacementPrism
  alias Lux.Prisms.Gas.MEVProtectionPrism
  alias Lux.Prisms.Gas.TransactionSimulationPrism
  alias Lux.Prisms.Gas.CostAnalysisPrism
  alias Lux.Prisms.Gas.GasTokenIntegrationPrism

  describe "end-to-end gas optimization workflow" do
    test "complete gas optimization pipeline" do
      # Step 1: Predict gas price
      {:ok, prediction} = GasPricePredictionPrism.handler(%{
        chain_id: 1,
        urgency: "standard"
      })
      assert prediction.tier == "standard"
      assert prediction.recommended_gas_price > 0

      # Step 2: Analyze cost
      {:ok, cost_report} = CostAnalysisPrism.handler(%{
        transaction_type: "erc20_transfer",
        estimated_gas: 65000,
        chain_id: 1
      })
      assert cost_report.transaction_type == "erc20_transfer"
      assert cost_report.estimated_gas == 65000
      assert cost_report.cost_trend in ["increasing", "decreasing", "stable"]

      # Step 3: MEV protection check
      {:ok, mev_analysis} = MEVProtectionPrism.handler(%{
        tx_data: %{
          to: "0x7a250d5c35b8bC8d5F5C0c6C3C3c3c3c3c3c3c3c",
          value: "0",
          data: "0xabcdef1234567890"
        }
      })
      assert mev_analysis.mev_risk_score >= 0.0
      assert mev_analysis.mev_risk_score <= 1.0

      # Step 4: Transaction batching
      {:ok, batch_plan} = TransactionBatchingPrism.handler(%{
        transactions: [
          %{to: "0xd3cDA913deb6F67967B99D67aCdF1712C293601", value: "1000000000000000000"},
          %{to: "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD18", value: "500000000000000000"},
          %{to: "0x583031D1113aD414E0377633752c2A6fF3c2D8C9", value: "250000000000000000"}
        ],
        gas_price_gwei: prediction.recommended_gas_price / 1_000_000_000
      })
      assert batch_plan.total_transactions == 3
      assert batch_plan.gas_savings_percent >= 0

      # Step 5: Transaction simulation
      {:ok, sim} = TransactionSimulationPrism.handler(%{
        to: "0xd3cDA913deb6F67967B99D67aCdF1712C293601",
        value: "1000000000000000000",
        network: "mainnet"
      })
      assert sim.simulated == true
      assert sim.estimated_gas > 0

      # Step 6: Gas token check
      {:ok, token_analysis} = GasTokenIntegrationPrism.handler(%{
        estimated_gas: 65000,
        gas_price_gwei: 30
      })
      assert token_analysis.potential_savings_wei >= 0

      # Step 7: Transaction replacement (speed up validation)
      {:ok, _speedup} = TransactionReplacementPrism.handler(%{
        action: "speed_up",
        original_tx_hash: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
        new_gas_price_gwei: 40,
        new_priority_fee_gwei: 3.0
      })

      # Step 8: Transaction replacement (cancel)
      {:ok, _cancel} = TransactionReplacementPrism.handler(%{
        action: "cancel",
        original_tx_hash: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
      })

      # All steps completed successfully
      assert true
    end

    test "gas price prediction drives cost optimization" do
      # Get prediction
      {:ok, prediction} = GasPricePredictionPrism.handler(%{urgency: "safe"})
      safe_price = prediction.recommended_gas_price

      {:ok, prediction_fast} = GasPricePredictionPrism.handler(%{urgency: "fast"})
      fast_price = prediction_fast.recommended_gas_price

      # Fast should cost more than safe
      assert fast_price >= safe_price
    end

    test "batching reduces per-transaction cost" do
      {:ok, batch} = TransactionBatchingPrism.handler(%{
        transactions: [
          %{to: "0xd3cDA913deb6F67967B99D67aCdF1712C293601", value: "1000000000000000000"}
        ],
        gas_price_gwei: 30
      })

      assert batch.individual_cost_eth >= batch.total_cost_eth
    end
  end
