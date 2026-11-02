defmodule Lux.Web3.WalletInfrastructure.GasManagerTest do
  use UnitCase, async: true

  alias Lux.Web3.WalletInfrastructure.GasManager

  describe "estimate_gas_tiers/2" do
    test "computes slow, standard, and fast tiers for Ethereum and L2 chains" do
      report_eth = GasManager.estimate_gas_tiers(1, 21_000)

      assert report_eth.chain_id == 1
      assert report_eth.fast.max_fee_per_gas > report_eth.standard.max_fee_per_gas
      assert report_eth.standard.max_fee_per_gas > report_eth.slow.max_fee_per_gas
      assert report_eth.standard.estimated_total_fee_eth > 0.0

      # Arbitrum should have vastly lower gas
      report_arb = GasManager.estimate_gas_tiers(42161, 21_000)
      assert report_arb.standard.max_fee_per_gas < report_eth.standard.max_fee_per_gas
    end
  end

  describe "calculate_speed_up_fee/2" do
    test "applies +15% multiplier to replace pending underpriced transactions" do
      res = GasManager.calculate_speed_up_fee(30_000_000_000, 2_000_000_000)

      assert res.max_fee_per_gas == 34_500_000_000
      assert res.max_priority_fee_per_gas == 2_300_000_000
    end
  end

  describe "estimate_gas_limit/2" do
    test "correctly sizes gas limits for native and ERC-20 transfers" do
      assert GasManager.estimate_gas_limit("0x123", "0x") == 21_000
      assert GasManager.estimate_gas_limit("0x123", "0xa9059cbb0000000000") == 65_000
      assert GasManager.estimate_gas_limit("0x123", "0xdeadbeef") == 250_000
    end
  end
end
