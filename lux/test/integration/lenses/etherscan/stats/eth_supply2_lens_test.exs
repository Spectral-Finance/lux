defmodule Lux.Integration.Etherscan.EthSupply2LensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.EthSupply2
  alias Lux.Lenses.Etherscan.RateLimitedAPI

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    throttle_standard_api()
    :ok
  end

  defmodule NoAuthEthSupply2Lens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan ETH Supply2 API",
      description: "Fetches the current amount of Ether in circulation, ETH2 Staking rewards, and EIP1559 burnt fees",
      url: "https://api.etherscan.io/v2/api",
      method: :get,
      headers: [{"content-type", "application/json"}]

    @doc """
    Prepares parameters before making the API request.
    """
    def before_focus(params) do
      # Set module and action for this endpoint
      params
      |> Map.put(:module, "stats")
      |> Map.put(:action, "ethsupply2")
    end
  end

  test "can fetch ETH supply2 information" do
    assert {:ok, %{result: eth_supply_details, eth_supply_details: eth_supply_details}} =
             RateLimitedAPI.call_standard(EthSupply2, :focus, [%{
               chainid: 1
             }])

    # Verify the structure of the response
    assert is_map(eth_supply_details)
    assert Map.has_key?(eth_supply_details, :eth_supply)
    assert Map.has_key?(eth_supply_details, :eth2_staking)
    assert Map.has_key?(eth_supply_details, :burnt_fees)
    assert Map.has_key?(eth_supply_details, :withdrawn_eth)

    # Log the values for informational purposes
    IO.puts("ETH Supply: #{eth_supply_details.eth_supply / 1.0e18} ETH")
    IO.puts("ETH2 Staking: #{eth_supply_details.eth2_staking / 1.0e18} ETH")
    IO.puts("Burnt Fees: #{eth_supply_details.burnt_fees / 1.0e18} ETH")
    IO.puts("Withdrawn ETH: #{eth_supply_details.withdrawn_eth / 1.0e18} ETH")

    # Verify the values are reasonable
    assert eth_supply_details.eth_supply > 100_000_000 * 1.0e18 # More than 100M ETH in wei
    assert eth_supply_details.eth2_staking > 0
    assert eth_supply_details.burnt_fees > 0
    assert eth_supply_details.withdrawn_eth > 0
  end

  test "requires chainid parameter for v2 API" do
    # The v2 API requires the chainid parameter
    result = RateLimitedAPI.call_standard(EthSupply2, :focus, [%{}])

    case result do
      {:error, %{message: "NOTOK", result: error_message}} ->
        # Should return an error about missing chainid parameter
        assert String.contains?(error_message, "Missing chainid parameter")
        IO.puts("Expected error for missing chainid: #{error_message}")

      {:ok, _} ->
        flunk("Expected an error for missing chainid parameter")
    end
  end

  test "fails when no auth is provided" do
    # The NoAuthEthSupply2Lens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthEthSupply2Lens, :focus, [%{
      chainid: 1
    }])

    case result do
      {:ok, %{"status" => "0", "message" => "NOTOK", "result" => error_message}} ->
        assert String.contains?(error_message, "Missing/Invalid API Key")

      {:error, error} ->
        # If it returns an error tuple, that's also acceptable
        assert error != nil
    end
  end
end
