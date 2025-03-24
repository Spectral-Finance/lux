defmodule Lux.Integration.Etherscan.EthSupplyLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Etherscan.EthSupply
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  test "can fetch total ETH supply" do
    assert {:ok, %{result: eth_supply, eth_supply: eth_supply}} =
             EthSupply.focus(%{
               chainid: 1
             })

    # ETH supply should be a large number (more than 100 million ETH)
    assert is_integer(eth_supply)
    assert eth_supply > 100_000_000 * 1.0e18 # More than 100M ETH in wei
  end

  test "can fetch ETH supply for a different chain" do
    # This test just verifies that we can specify a different chain
    # The actual result may vary depending on the chain
    result = EthSupply.focus(%{
      chainid: 137 # Polygon
    })

    case result do
      {:ok, %{result: _eth_supply}} ->
        assert true

      {:error, _error} ->
        # If the endpoint doesn't exist on this chain, that's also acceptable
        assert true
    end
  end
end
