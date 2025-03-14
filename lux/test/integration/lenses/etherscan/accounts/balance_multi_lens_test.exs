defmodule Lux.Integration.Etherscan.BalanceMultiLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Etherscan.BalanceMulti
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Vitalik's address
  @vitalik "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
  # Ethereum Foundation address
  @eth_foundation "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe"

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  test "can fetch ETH balances for multiple addresses" do
    assert {:ok, %{result: balances}} =
             BalanceMulti.focus(%{
               addresses: [@vitalik, @eth_foundation],
               chainid: 1
             })

    # Verify we got results for both addresses
    assert length(balances) == 2

    # Find Vitalik's and Ethereum Foundation's balances
    vitalik_balance = Enum.find(balances, &(&1["account"] == @vitalik))
    eth_foundation_balance = Enum.find(balances, &(&1["account"] == @eth_foundation))

    # Verify both balances were found
    assert vitalik_balance, "Vitalik's balance not found in response"
    assert eth_foundation_balance, "Ethereum Foundation's balance not found in response"

    # Convert balances from wei to ether for easier validation
    vitalik_balance_in_eth = String.to_integer(vitalik_balance["balance"]) / 1.0e18
    eth_foundation_balance_in_eth = String.to_integer(eth_foundation_balance["balance"]) / 1.0e18

    # Both addresses should have some ETH (more than 0)
    assert vitalik_balance_in_eth > 0
    assert eth_foundation_balance_in_eth > 0
  end

  test "can specify a different tag (block parameter)" do
    assert {:ok, %{result: balances}} =
             BalanceMulti.focus(%{
               addresses: [@vitalik, @eth_foundation],
               chainid: 1,
               tag: "latest"
             })

    assert length(balances) == 2
  end
end
