defmodule Lux.Integration.Etherscan.EthSupply2LensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Etherscan.EthSupply2
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  test "can fetch ETH supply2 information" do
    assert {:ok, %{result: eth_supply_details, eth_supply_details: eth_supply_details}} =
             EthSupply2.focus(%{
               chainid: 1
             })

    # Verify the structure of the response
    assert is_map(eth_supply_details)
    assert Map.has_key?(eth_supply_details, :eth_supply)
    assert Map.has_key?(eth_supply_details, :eth2_staking)
    assert Map.has_key?(eth_supply_details, :burnt_fees)
    assert Map.has_key?(eth_supply_details, :withdrawn_eth)

    # Verify the values are reasonable
    assert eth_supply_details.eth_supply > 100_000_000 * 1.0e18 # More than 100M ETH in wei
    assert eth_supply_details.eth2_staking > 0
    assert eth_supply_details.burnt_fees > 0
    assert eth_supply_details.withdrawn_eth > 0
  end
end
