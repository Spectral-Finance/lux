defmodule Lux.Integration.Etherscan.BalanceHistoryLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Etherscan.BalanceHistory
  alias Lux.Lenses.Etherscan.Base
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Ethereum Foundation address
  @eth_foundation "0xde0B295669a9FD93d5F28D9Ec85E40f4cb697BAe"
  # Block number to check (Ethereum block from 2019)
  @block_number 8_000_000

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_pro_api

  # Helper function to check if we have a Pro API key
  defp has_pro_api_key? do
    case Base.check_pro_endpoint("account", "balancehistory") do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  test "can fetch historical ETH balance for an address at a specific block" do
    # Skip this test if we don't have a Pro API key
    if has_pro_api_key?() do
      assert {:ok, %{result: balance}} =
               BalanceHistory.focus(%{
                 address: @eth_foundation,
                 blockno: @block_number,
                 chainid: 1
               })

      # Convert balance from wei to ether for easier validation
      balance_in_eth = String.to_integer(balance) / 1.0e18

      # The Ethereum Foundation should have had some ETH at this block
      assert is_binary(balance)
      assert balance_in_eth > 0
    end
  end
end
