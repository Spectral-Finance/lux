defmodule Lux.Web3.WalletInfrastructure.BalanceTrackerTest do
  use UnitCase, async: true

  alias Lux.Web3.WalletInfrastructure.BalanceTracker

  describe "fetch_multi_chain_balances/2 and wei_to_ether/1" do
    test "aggregates native token balances across supported EVM networks" do
      addr = "0xd8da6bf26964af9d7eed9e03e53415d37aa96045"
      mock_balances = %{
        1 => 2_000_000_000_000_000_000, # 2.0 ETH
        137 => 500_000_000_000_000_000_000 # 500 POL
      }

      portfolio = BalanceTracker.fetch_multi_chain_balances(addr, mock_balances)

      assert portfolio.address == addr
      assert portfolio.total_usd_value > 0.0
      assert length(portfolio.chains) >= 5

      eth_entry = Enum.find(portfolio.chains, &(&1.chain_id == 1))
      assert eth_entry.symbol == "ETH"
      assert eth_entry.balance_formatted == 2.0
    end

    test "wei_to_ether converts exact decimal values" do
      assert BalanceTracker.wei_to_ether(1_000_000_000_000_000_000) == 1.0
      assert BalanceTracker.wei_to_ether(500_000_000_000_000_000) == 0.5
    end
  end
end
